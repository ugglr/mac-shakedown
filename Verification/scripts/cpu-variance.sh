#!/bin/bash
# cpu-variance.sh — sustained parallel SHA-256, time-capped iterations on a
# pre-warmed (saturated) chassis. Detects batch-level performance variance
# (~41.5% multi-core variance reported on M5 Max bad batches in early 2026).
#
# Test design:
#   1) BURST_SEC of cold-start measurement     (chassis cool, captures peak boost)
#   2) WARMUP_SEC of continuous load           (chassis to thermal equilibrium)
#   3) ITERATIONS × SECONDS_PER_ITER timed runs (steady-state throughput, MB/s)
#   4) Compute spread, max-to-min ratio, early-vs-late decline, and
#      burst-vs-steady ratio (catches always-throttled units that look "consistent")
#
# Output: JSON to stdout. Per-iteration progress to stderr.
#
# Env knobs:
#   BURST_SEC         default 5    (cold-start burst window; set to 0 to skip)
#   WARMUP_SEC        default depends on CHASSIS_CLASS
#                       fanless          → 60s   (saturates fast)
#                       active-cooled-pro → 300s (saturation takes 5–8 min on 16")
#                       desktop          → 180s
#   ITERATIONS        default 5
#   SECONDS_PER_ITER  default 60
#   WORKERS           default = P-cores
#   CHASSIS_CLASS     default active-cooled-pro
#                       affects WARMUP_SEC default only
#
# Thorough run on a fresh M5 Max:
#   WARMUP_SEC=420 SECONDS_PER_ITER=90 ITERATIONS=5 ./cpu-variance.sh   (~15 min)

set -euo pipefail

CHASSIS_CLASS=${CHASSIS_CLASS:-active-cooled-pro}

# Default warmup by chassis class
case "$CHASSIS_CLASS" in
  fanless)            DEFAULT_WARMUP=60 ;;
  active-cooled-pro)  DEFAULT_WARMUP=300 ;;
  desktop)            DEFAULT_WARMUP=180 ;;
  *)
    echo "cpu-variance.sh: unknown CHASSIS_CLASS='$CHASSIS_CLASS'" >&2
    echo "  use one of: fanless | active-cooled-pro | desktop" >&2
    exit 2
    ;;
esac

BURST_SEC=${BURST_SEC:-5}
WARMUP_SEC=${WARMUP_SEC:-$DEFAULT_WARMUP}
ITERATIONS=${ITERATIONS:-5}
SECONDS_PER_ITER=${SECONDS_PER_ITER:-60}
WORKERS=${WORKERS:-$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null \
                      || sysctl -n hw.physicalcpu 2>/dev/null \
                      || sysctl -n hw.ncpu 2>/dev/null \
                      || echo 0)}

if [[ -z "$WORKERS" || "$WORKERS" -lt 1 ]]; then
  echo "cpu-variance.sh: could not determine worker count (sysctl failed)" >&2
  exit 2
fi

TOTAL=$((BURST_SEC + WARMUP_SEC + ITERATIONS * SECONDS_PER_ITER))
echo "cpu-variance: chassis=$CHASSIS_CLASS, burst=${BURST_SEC}s, warmup=${WARMUP_SEC}s, then $ITERATIONS × ${SECONDS_PER_ITER}s timed iters; $WORKERS workers (~${TOTAL}s = $((TOTAL / 60))m total)" >&2

python3 - "$BURST_SEC" "$WARMUP_SEC" "$ITERATIONS" "$SECONDS_PER_ITER" "$WORKERS" "$CHASSIS_CLASS" <<'PYEOF'
import hashlib
import json
import multiprocessing
import statistics
import sys
import time

# macOS Python defaults to "spawn", which re-imports the script — fails for stdin.
multiprocessing.set_start_method("fork", force=True)

BURST_SEC        = int(sys.argv[1])
WARMUP_SEC       = int(sys.argv[2])
ITERATIONS       = int(sys.argv[3])
SECONDS_PER_ITER = int(sys.argv[4])
WORKERS          = int(sys.argv[5])
CHASSIS_CLASS    = sys.argv[6]

DATA = bytes(1024 * 1024)  # 1 MB of zeros — SHA-256 has no data-dependent fast paths

def worker(stop_at):
    h = hashlib.sha256()
    ops = 0
    while time.time() < stop_at:
        for _ in range(64):
            h.update(DATA)
        ops += 64
    return ops

def run_window(seconds):
    stop_at = time.time() + seconds
    t = time.perf_counter()
    with multiprocessing.Pool(WORKERS) as pool:
        ops_list = pool.map(worker, [stop_at] * WORKERS)
    elapsed = time.perf_counter() - t
    total_mb = sum(ops_list)
    return total_mb / elapsed if elapsed > 0 else 0.0, total_mb, elapsed

# ---- 1) Cold-start burst ----
burst_throughput = None
if BURST_SEC > 0:
    print(f"  burst: {BURST_SEC}s cold-start measurement…", file=sys.stderr)
    burst_throughput, burst_mb, burst_elapsed = run_window(BURST_SEC)
    print(f"  burst: {burst_mb:,} MB in {burst_elapsed:.2f}s = {burst_throughput:,.0f} MB/s",
          file=sys.stderr)

# ---- 2) Warmup (discarded for variance) — chunked so we capture the tail ----
warmup_tail_throughput = None
if WARMUP_SEC > 0:
    print(f"  warmup: {WARMUP_SEC}s to reach thermal equilibrium…", file=sys.stderr)
    chunk_secs = min(30, WARMUP_SEC)
    remaining = WARMUP_SEC
    last_chunk_throughput = None
    while remaining > 0:
        sec = min(chunk_secs, remaining)
        last_chunk_throughput, _, _ = run_window(sec)
        remaining -= sec
    warmup_tail_throughput = last_chunk_throughput
    print(f"  warmup done (tail = {warmup_tail_throughput:,.0f} MB/s — discarded for spread)",
          file=sys.stderr)

# ---- 3) Timed iterations ----
throughputs = []
for i in range(ITERATIONS):
    tput, total_mb, elapsed = run_window(SECONDS_PER_ITER)
    throughputs.append(tput)
    print(f"  iter {i+1}/{ITERATIONS}: {total_mb:,} MB in {elapsed:.2f}s = {tput:,.0f} MB/s",
          file=sys.stderr)

# ---- 4) Statistics ----
mean = statistics.mean(throughputs)
stdev = statistics.stdev(throughputs) if len(throughputs) > 1 else 0.0
spread_pct = (max(throughputs) - min(throughputs)) / mean * 100 if mean else 0
ratio_max = max(throughputs) / min(throughputs) if min(throughputs) > 0 else 1.0

# Trend: early-half mean vs late-half mean. A monotonic decline is the
# signature of a hot spot reaching threshold mid-test that spread can miss.
decline_pct = None
if len(throughputs) >= 4:
    half = len(throughputs) // 2
    early = statistics.mean(throughputs[:half])
    late = statistics.mean(throughputs[half:])
    decline_pct = round((early - late) / early * 100, 3) if early else None

# Burst-to-steady ratio: catches "always-throttled" units that look consistent
# in the iterations because they were already throttled at the warmup tail.
# Healthy chassis: steady < burst (some thermal headroom given up).
# Always-throttled bad unit: steady ≈ burst (no thermal headroom to give up).
burst_to_steady_ratio = None
if burst_throughput and burst_throughput > 0:
    burst_to_steady_ratio = round(mean / burst_throughput, 4)

# ---- 5) Verdict ----
verdict = "pass"
reasons = []

# Spread
if spread_pct > 10:
    verdict = "fail"
    reasons.append(f"spread {spread_pct:.1f}% > 10%")
elif spread_pct > 5:
    verdict = "warn"
    reasons.append(f"spread {spread_pct:.1f}% in 5–10% warn range")

# Max-to-min ratio (with warn band per Pass-Fail Criteria)
if ratio_max >= 1.4:
    verdict = "fail"
    reasons.append(f"max-to-min ratio {ratio_max:.2f}× ≥ 1.4×")
elif ratio_max >= 1.2:
    if verdict == "pass": verdict = "warn"
    reasons.append(f"max-to-min ratio {ratio_max:.2f}× in 1.2–1.4× warn range")

# Decline (only meaningful with 4+ iterations)
if decline_pct is not None:
    if decline_pct > 10:
        verdict = "fail"
        reasons.append(f"throughput declined {decline_pct:.1f}% from early to late iterations")
    elif decline_pct > 5:
        if verdict == "pass": verdict = "warn"
        reasons.append(f"throughput declined {decline_pct:.1f}% in 5–10% warn range")

# Burst-to-steady (advisory — heuristic, no calibration baseline yet)
if burst_to_steady_ratio is not None and burst_to_steady_ratio > 0.97:
    if verdict == "pass": verdict = "warn"
    reasons.append(
        f"burst-to-steady ratio {burst_to_steady_ratio:.2f}× — steady matches burst, "
        f"unit may be throttling from cold (compare against calibration baseline)"
    )

if not reasons:
    reasons.append(
        f"spread {spread_pct:.2f}%, ratio {ratio_max:.2f}×"
        + (f", decline {decline_pct:.2f}%" if decline_pct is not None else "")
        + " — within healthy range"
    )

result = {
    "chassis_class": CHASSIS_CLASS,
    "burst_sec": BURST_SEC,
    "warmup_sec": WARMUP_SEC,
    "iterations": ITERATIONS,
    "seconds_per_iter": SECONDS_PER_ITER,
    "workers": WORKERS,
    "burst_throughput_mb_per_s": round(burst_throughput, 1) if burst_throughput else None,
    "warmup_tail_throughput_mb_per_s": round(warmup_tail_throughput, 1) if warmup_tail_throughput else None,
    "throughput_mb_per_s": [round(t, 1) for t in throughputs],
    "min_mb_per_s": round(min(throughputs), 1),
    "max_mb_per_s": round(max(throughputs), 1),
    "mean_mb_per_s": round(mean, 1),
    "stdev_mb_per_s": round(stdev, 1),
    "spread_pct": round(spread_pct, 3),
    "max_to_min_ratio": round(ratio_max, 3),
    "early_vs_late_decline_pct": decline_pct,
    "burst_to_steady_ratio": burst_to_steady_ratio,
    "verdict": verdict,
    "verdict_reasons": reasons,
}
print(json.dumps(result, indent=2))
PYEOF
