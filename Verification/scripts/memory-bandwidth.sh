#!/bin/bash
# memory-bandwidth.sh: STREAM-style sequential memory copy bandwidth.
#
# Spawns one worker per P-core, each copying its own pair of large buffers with
# ctypes.memmove in a tight loop, and sums the aggregate throughput. A single
# thread cannot saturate the multi-channel memory controllers on Apple Silicon
# (a lone memcpy tops out well below peak), so the test is multi-threaded the way
# STREAM is built with OpenMP.
#
# What it measures: sequential copy bandwidth (memcpy). Each copy reads N bytes
# and writes N bytes, so "touched" traffic is 2x the reported copy bandwidth.
# This is a lower bound on a full STREAM triad (copy / scale / add / triad);
# scale and add need elementwise arithmetic that pure-Python can't do at memory
# speed without a native kernel. memmove is the honest pure-stdlib proxy: it
# still catches a memory subsystem that is slow or inconsistent across runs.
#
# Buffers are sized to exceed the last-level / system-level cache so the copy is
# DRAM-bound, not cache-bound.
#
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   MEMBW_MB        default 1024  (TARGET total working set in MB across all
#                                  workers; split into 2 buffers per worker.
#                                  Auto-capped to fit RAM.)
#   MEMBW_ITERS     default 5     (timed iterations, for run-to-run variance)
#   MEMBW_SECONDS   default 2     (seconds per timed iteration)
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

echo "memory-bandwidth: ${MEMBW_MB}MB working set across $WORKERS workers, $MEMBW_ITERS x ${MEMBW_SECONDS}s" >&2

python3 - "$MEMBW_MB" "$MEMBW_ITERS" "$MEMBW_SECONDS" "$WORKERS" "$MEMSIZE" <<'PYEOF'
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

MB = 1024 * 1024
data_quality_notes = []

# Size each worker's buffers. Total working set is split into 2 buffers (src+dst)
# per worker. Floor per-buffer at 64 MB so it comfortably exceeds per-core L2 and
# the aggregate exceeds the system-level cache (DRAM-bound, not cache-bound).
MIN_BUFFER_MB = 64
per_buffer_mb = max(MIN_BUFFER_MB, TARGET_MB // (2 * WORKERS))

# RAM guard: keep the working set under 40% of physical memory so we don't push
# the machine into swap (which would measure the SSD, not RAM). Scale down, and
# skip only if we cannot keep buffers above a cache-busting 32 MB.
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
            "workers": WORKERS,
            "verdict": "skipped",
            "data_quality": "skipped",
            "data_quality_notes": [
                f"not enough RAM to size cache-busting buffers for {WORKERS} "
                f"workers ({MEMSIZE_BYTES // MB} MB total); lower WORKERS or "
                f"raise MEMBW_MB on a machine with more memory"
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
    # Fault every page in and prime, OUTSIDE the timed region.
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
    # Workers run concurrently; the longest worker bounds the wall window.
    wall = max((r[1] for r in results), default=0.0)
    copy_bw = total_bytes / wall if wall > 0 else 0.0  # bytes copied/s (N per memmove)
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
