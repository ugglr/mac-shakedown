#!/bin/bash
# memory-bandwidth.sh: STREAM-style memory bandwidth.
#
# Prefers the vendored STREAM triad (stream-triad.c: real Copy / Scale / Add /
# Triad across one thread per P-core), compiled at runtime with the clang that
# ships in the Xcode Command Line Tools. No network, no shipped binary: the C
# source is in the repo, compiled to a tempfile, run, deleted. When clang is
# unavailable it falls back to a pure-Python ctypes.memmove copy proxy, so the
# phase always produces a number.
#
# What it measures: DRAM bandwidth. A single thread cannot saturate the
# multi-channel controllers on Apple Silicon, so the kernels are multi-threaded
# the way STREAM uses OpenMP. Buffers are sized past the system-level cache.
#
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   MEMBW_MB        default 1024  (TARGET total working set in MB, auto-capped to
#                                  40% of RAM; split across 3 arrays for the triad
#                                  or 2 buffers per worker for the proxy)
#   MEMBW_ITERS     default 5     (reps, for run-to-run variance)
#   MEMBW_SECONDS   default 2     (seconds per iteration, memmove proxy only)
#   WORKERS         default = P-cores

set -euo pipefail

MEMBW_MB=${MEMBW_MB:-1024}
MEMBW_ITERS=${MEMBW_ITERS:-5}
MEMBW_SECONDS=${MEMBW_SECONDS:-2}

for v in MEMBW_MB MEMBW_ITERS MEMBW_SECONDS; do
  if ! [[ "${!v}" =~ ^[0-9]+$ ]] || (( ${!v} < 1 )); then
    echo "memory-bandwidth.sh: $v must be a positive integer (got '${!v}')" >&2
    exit 2
  fi
done

# WORKERS: probe P-cores then fall back; treat empty string as unset.
if [[ -z "${WORKERS:-}" ]]; then
  WORKERS=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null \
            || sysctl -n hw.physicalcpu 2>/dev/null \
            || sysctl -n hw.ncpu 2>/dev/null \
            || echo "")
fi
if ! [[ "$WORKERS" =~ ^[0-9]+$ ]] || (( WORKERS < 1 )); then
  echo "memory-bandwidth.sh: could not determine worker count (sysctl failed)" >&2
  exit 2
fi

MEMSIZE=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STREAM_SRC="$SCRIPT_DIR/stream-triad.c"

# Budget the working set at 40% of physical RAM so we never push into swap.
budget_mb=$MEMBW_MB
if [[ "$MEMSIZE" =~ ^[0-9]+$ ]] && (( MEMSIZE > 0 )); then
  ram_mb=$(( MEMSIZE / 1024 / 1024 ))
  cap_mb=$(( ram_mb * 40 / 100 ))
  if (( budget_mb > cap_mb )); then budget_mb=$cap_mb; fi
fi

# ---- Preferred path: vendored STREAM triad compiled with clang ----
if command -v clang >/dev/null 2>&1 && [[ -f "$STREAM_SRC" ]]; then
  per_array_mb=$(( budget_mb / 3 ))
  if (( per_array_mb >= 64 )); then
    STREAM_BIN=$(mktemp -t shakedown-stream.XXXXXX)
    trap 'rm -f "$STREAM_BIN"' EXIT INT TERM
    if clang -O3 -pthread "$STREAM_SRC" -o "$STREAM_BIN" 2>/dev/null; then
      per_array_bytes=$(( per_array_mb * 1024 * 1024 ))
      echo "memory-bandwidth: STREAM triad, ${per_array_mb}MB/array x3, $WORKERS threads, $MEMBW_ITERS reps" >&2
      T0=$(date +%s)
      if RAW=$("$STREAM_BIN" "$per_array_bytes" "$WORKERS" "$MEMBW_ITERS" 2>/dev/null); then
        T1=$(date +%s)
        python3 - "$RAW" "$WORKERS" "$per_array_mb" "$((T1 - T0))" <<'PYEOF'
import json
import statistics
import sys

raw = json.loads(sys.argv[1])
workers = int(sys.argv[2])
per_array_mb = int(sys.argv[3])
wall = int(sys.argv[4])
res = raw["results"]


def mean(xs):
    return round(statistics.mean(xs), 2) if xs else 0.0


triad = res["triad"]
t_mean = mean(triad)
t_min = round(min(triad), 2) if triad else 0.0
t_max = round(max(triad), 2) if triad else 0.0
spread = round((t_max - t_min) / t_mean * 100, 2) if t_mean else 0.0
c_mean, s_mean, a_mean = mean(res["copy"]), mean(res["scale"]), mean(res["add"])

result = {
    "workload": "STREAM-style triad (vendored C, pthreads), DRAM-bound",
    "method": "stream-triad",
    "workers": workers,
    "working_set_mb": per_array_mb * 3,
    "reps": raw.get("reps"),
    "copy_gb_per_s": res["copy"],
    "scale_gb_per_s": res["scale"],
    "add_gb_per_s": res["add"],
    "triad_gb_per_s": triad,
    "mean_copy_gb_per_s": c_mean,
    "mean_scale_gb_per_s": s_mean,
    "mean_add_gb_per_s": a_mean,
    "mean_triad_gb_per_s": t_mean,
    "min_triad_gb_per_s": t_min,
    "max_triad_gb_per_s": t_max,
    "spread_pct": spread,
    "wall_seconds": wall,
    "data_quality": "ok",
    "data_quality_notes": [],
    "verdict": "info",
    "verdict_reasons": [
        f"triad mean {t_mean:,.1f} GB/s (copy {c_mean:,.1f}, scale {s_mean:,.1f}, "
        f"add {a_mean:,.1f}) across {workers} threads, spread {spread:.1f}%",
        "informational in v0.2; calibrated pass/fail thresholds land in v0.3"
    ],
}
print(json.dumps(result, indent=2))
PYEOF
        exit 0
      fi
    fi
  fi
  echo "memory-bandwidth: STREAM triad unavailable (clang/compile/size), using memmove proxy" >&2
  TRIAD_FALLBACK="STREAM triad unavailable (clang missing, compile failed, or too little RAM); used the pure-Python memmove proxy instead"
fi

# ---- Fallback: pure-Python ctypes.memmove copy proxy ----
echo "memory-bandwidth: ${MEMBW_MB}MB working set across $WORKERS workers (memmove proxy)" >&2

python3 - "$MEMBW_MB" "$MEMBW_ITERS" "$MEMBW_SECONDS" "$WORKERS" "$MEMSIZE" "${TRIAD_FALLBACK:-}" <<'PYEOF'
import ctypes
import json
import multiprocessing
import statistics
import sys
import time

# macOS Python defaults to "spawn" which re-imports the script and fails for
# stdin-defined workers; force "fork" so the pool inherits this module.
multiprocessing.set_start_method("fork", force=True)

TARGET_MB     = int(sys.argv[1])
ITERATIONS    = int(sys.argv[2])
SECONDS       = int(sys.argv[3])
WORKERS       = int(sys.argv[4])
MEMSIZE_BYTES = int(sys.argv[5])
FALLBACK_NOTE = sys.argv[6]

MB = 1024 * 1024
data_quality_notes = [FALLBACK_NOTE] if FALLBACK_NOTE else []

MIN_BUFFER_MB = 64
per_buffer_mb = max(MIN_BUFFER_MB, TARGET_MB // (2 * WORKERS))

if MEMSIZE_BYTES > 0:
    budget_mb = int(MEMSIZE_BYTES / MB * 0.40)
    max_buffer_mb = budget_mb // (2 * WORKERS)
    if per_buffer_mb > max_buffer_mb:
        per_buffer_mb = max_buffer_mb
        data_quality_notes.append(
            f"working set capped to fit RAM: {per_buffer_mb} MB per buffer "
            f"({MEMSIZE_BYTES // MB} MB total RAM, 40% budget)"
        )
    if per_buffer_mb < 32:
        print(json.dumps({
            "workload": "multi-threaded sequential memcpy (ctypes.memmove)",
            "method": "memmove-proxy",
            "workers": WORKERS,
            "verdict": "skipped",
            "data_quality": "skipped",
            "data_quality_notes": data_quality_notes + [
                f"not enough RAM to size cache-busting buffers for {WORKERS} "
                f"workers ({MEMSIZE_BYTES // MB} MB total)"
            ],
            "verdict_reasons": ["insufficient RAM for a DRAM-bound test; phase skipped"],
        }, indent=2))
        sys.exit(0)

per_buffer_bytes = per_buffer_mb * MB
working_set_mb = WORKERS * 2 * per_buffer_mb


def worker(args):
    per_bytes, seconds = args
    src = bytearray(per_bytes)
    dst = bytearray(per_bytes)
    csrc = (ctypes.c_char * per_bytes).from_buffer(src)
    cdst = (ctypes.c_char * per_bytes).from_buffer(dst)
    ctypes.memset(csrc, 1, per_bytes)
    ctypes.memset(cdst, 2, per_bytes)
    memmove = ctypes.memmove
    memmove(cdst, csrc, per_bytes)
    copies = 0
    start = time.perf_counter()
    stop_at = start + seconds
    while time.perf_counter() < stop_at:
        memmove(cdst, csrc, per_bytes)
        copies += 1
    elapsed = time.perf_counter() - start
    return copies * per_bytes, elapsed


def run_window(seconds):
    with multiprocessing.Pool(WORKERS) as pool:
        results = pool.map(worker, [(per_buffer_bytes, seconds)] * WORKERS)
    total_bytes = sum(r[0] for r in results)
    wall = max((r[1] for r in results), default=0.0)
    copy_bw = total_bytes / wall if wall > 0 else 0.0
    return copy_bw, wall


copy_bw_gb = []
total_wall = 0.0
for i in range(ITERATIONS):
    bw, wall = run_window(SECONDS)
    total_wall += wall
    gb = bw / 1e9
    copy_bw_gb.append(round(gb, 2))
    print(f"  iter {i+1}/{ITERATIONS}: {gb:,.1f} GB/s copied "
          f"(~{gb*2:,.1f} GB/s touched, read+write)", file=sys.stderr)

mean_gb = statistics.mean(copy_bw_gb) if copy_bw_gb else 0.0
min_gb = min(copy_bw_gb) if copy_bw_gb else 0.0
max_gb = max(copy_bw_gb) if copy_bw_gb else 0.0
spread_pct = round((max_gb - min_gb) / mean_gb * 100, 2) if mean_gb else 0.0

data_quality = "ok"
if per_buffer_mb < MIN_BUFFER_MB:
    data_quality = "few_samples"
    data_quality_notes.append(
        f"per-buffer size {per_buffer_mb} MB is below the {MIN_BUFFER_MB} MB "
        f"cache-busting floor; numbers may be cache-influenced and read high"
    )

result = {
    "workload": "multi-threaded sequential memcpy (ctypes.memmove), DRAM-bound",
    "method": "memmove-proxy",
    "workers": WORKERS,
    "per_buffer_mb": per_buffer_mb,
    "total_working_set_mb": working_set_mb,
    "iterations": ITERATIONS,
    "seconds_per_iter": SECONDS,
    "copy_bandwidth_gb_per_s": copy_bw_gb,
    "mean_copy_gb_per_s": round(mean_gb, 2),
    "min_copy_gb_per_s": round(min_gb, 2),
    "max_copy_gb_per_s": round(max_gb, 2),
    "spread_pct": spread_pct,
    "touched_bandwidth_gb_per_s_mean": round(mean_gb * 2, 2),
    "wall_seconds": round(total_wall, 3),
    "data_quality": data_quality,
    "data_quality_notes": data_quality_notes,
    "verdict": "info",
    "verdict_reasons": [
        f"mean copy {mean_gb:,.1f} GB/s (read+write ~{mean_gb*2:,.1f} GB/s touched) "
        f"across {WORKERS} workers, spread {spread_pct:.1f}%",
        "informational in v0.2; calibrated pass/fail thresholds land in v0.3"
    ],
}
print(json.dumps(result, indent=2))
PYEOF
