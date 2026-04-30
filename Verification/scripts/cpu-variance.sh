#!/bin/bash
# cpu-variance.sh — sustained parallel SHA-256, time-capped iterations on a
# pre-warmed (saturated) chassis. Detects M5 Max bad-batch performance variance
# (~41.5% multi-core variance reported on affected units).
#
# Test design:
#   1) WARMUP_SEC of continuous load to bring the chassis to thermal equilibrium
#      (eliminates "iteration 1 cold, iteration 5 hot" false-positive variance)
#   2) Then ITERATIONS × SECONDS_PER_ITER timed runs measuring throughput (MB/s)
#   3) Compute spread, max-to-min ratio, and decline trend (early vs late halves)
#
# Output: JSON to stdout. Per-iteration progress to stderr.
#
# Env knobs:
#   WARMUP_SEC         default 90   (set to 0 to skip)
#   ITERATIONS         default 5
#   SECONDS_PER_ITER   default 60
#   WORKERS            default = P-cores
#
# For a really thorough check on a fresh M5 Max:
#   WARMUP_SEC=120 SECONDS_PER_ITER=90 ITERATIONS=5 ./cpu-variance.sh
#   (= ~10 min total, hits steady-state thoroughly)

set -euo pipefail

WARMUP_SEC=${WARMUP_SEC:-90}
ITERATIONS=${ITERATIONS:-5}
SECONDS_PER_ITER=${SECONDS_PER_ITER:-60}
WORKERS=${WORKERS:-$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || sysctl -n hw.physicalcpu)}

TOTAL=$((WARMUP_SEC + ITERATIONS * SECONDS_PER_ITER))
echo "cpu-variance: ${WARMUP_SEC}s warmup, then $ITERATIONS × ${SECONDS_PER_ITER}s timed iters; $WORKERS workers (~${TOTAL}s = $((TOTAL / 60))m total)" >&2

python3 - "$WARMUP_SEC" "$ITERATIONS" "$SECONDS_PER_ITER" "$WORKERS" <<'PYEOF'
import hashlib
import json
import multiprocessing
import statistics
import sys
import time

# macOS Python defaults to "spawn", which re-imports the script — fails for stdin.
multiprocessing.set_start_method("fork", force=True)

WARMUP_SEC = int(sys.argv[1])
ITERATIONS = int(sys.argv[2])
SECONDS_PER_ITER = int(sys.argv[3])
WORKERS = int(sys.argv[4])

DATA = bytes(1024 * 1024)  # 1 MB of zeros — deterministic input

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
    return total_mb, elapsed

# ---- Warmup (discarded) ----
if WARMUP_SEC > 0:
    print(f"  warmup: holding load for {WARMUP_SEC}s to reach thermal equilibrium…", file=sys.stderr)
    warm_mb, warm_elapsed = run_window(WARMUP_SEC)
    warm_throughput = warm_mb / warm_elapsed if warm_elapsed else 0
    print(f"  warmup done ({warm_throughput:,.0f} MB/s — discarded)", file=sys.stderr)

# ---- Timed iterations ----
throughputs = []
for i in range(ITERATIONS):
    total_mb, elapsed = run_window(SECONDS_PER_ITER)
    mb_per_sec = total_mb / elapsed if elapsed > 0 else 0
    throughputs.append(mb_per_sec)
    print(
        f"  iter {i+1}/{ITERATIONS}: {total_mb:,} MB in {elapsed:.2f}s = {mb_per_sec:,.0f} MB/s",
        file=sys.stderr,
    )

# ---- Statistics ----
mean = statistics.mean(throughputs)
stdev = statistics.stdev(throughputs) if len(throughputs) > 1 else 0.0
spread_pct = (max(throughputs) - min(throughputs)) / mean * 100 if mean else 0
ratio_max = max(throughputs) / min(throughputs) if min(throughputs) > 0 else 1.0

# Trend: compare early-half mean to late-half mean. A monotonic decline is the
# specific signature of a hot spot reaching threshold mid-test.
decline_pct = 0.0
if len(throughputs) >= 4:
    half = len(throughputs) // 2
    early = statistics.mean(throughputs[:half])
    late = statistics.mean(throughputs[half:])
    decline_pct = (early - late) / early * 100 if early else 0.0

# ---- Verdict ----
verdict = "pass"
reasons = []
if spread_pct > 10:
    verdict = "fail"
    reasons.append(f"spread {spread_pct:.1f}% > 10%")
elif spread_pct > 5:
    verdict = "warn"
    reasons.append(f"spread {spread_pct:.1f}% in 5–10% warn range")

if ratio_max >= 1.4:
    verdict = "fail"
    reasons.append(f"max-to-min ratio {ratio_max:.2f}× ≥ 1.4×")

if decline_pct > 10:
    verdict = "fail"
    reasons.append(f"throughput declined {decline_pct:.1f}% from early to late iterations")
elif decline_pct > 5 and verdict == "pass":
    verdict = "warn"
    reasons.append(f"throughput declined {decline_pct:.1f}% from early to late iterations")

if not reasons:
    reasons.append(f"spread {spread_pct:.1f}%, decline {decline_pct:.1f}% — within normal range")

result = {
    "warmup_sec": WARMUP_SEC,
    "iterations": ITERATIONS,
    "seconds_per_iter": SECONDS_PER_ITER,
    "workers": WORKERS,
    "throughput_mb_per_s": [round(t, 1) for t in throughputs],
    "min_mb_per_s": round(min(throughputs), 1),
    "max_mb_per_s": round(max(throughputs), 1),
    "mean_mb_per_s": round(mean, 1),
    "stdev_mb_per_s": round(stdev, 1),
    "spread_pct": round(spread_pct, 3),
    "max_to_min_ratio": round(ratio_max, 3),
    "early_vs_late_decline_pct": round(decline_pct, 3),
    "verdict": verdict,
    "verdict_reasons": reasons,
}
print(json.dumps(result, indent=2))
PYEOF
