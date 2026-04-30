#!/bin/bash
# cpu-variance.sh — sustained parallel SHA-256, time-capped iterations on a
# pre-warmed (saturated) chassis. Detects batch-level performance variance
# (~41.5% multi-core variance reported on M5 Max bad batches in early 2026).
#
# CAVEAT — what this test actually measures:
# SHA-256 is hardware-accelerated on Apple Silicon. The test stresses the SHA
# engines, multiprocessing scheduling, and chassis thermal mass — but does NOT
# probe integer pipelines, memory bandwidth, or large-cache thermal behavior as
# deeply as Cinebench / Geekbench would. Public reports of the M5 Max defect
# came from those benchmarks; this test catches *correlated* signals (timing
# variance + thermal saturation behavior) but isn't 1:1 with their workloads.
# A non-accelerated workload pass is on the roadmap.
#
# Test design:
#   1) BURST_SEC of cold-start measurement      (peak boost throughput)
#   2) WARMUP_SEC of continuous load            (chassis to thermal equilibrium)
#   3) ITERATIONS × SECONDS_PER_ITER timed runs (steady-state throughput, MB/s)
#   4) Compute spread, max-to-min ratio, early-vs-late decline, and
#      burst-to-steady ratio (advisory — flags possible always-throttled units)
#
# Output: JSON to stdout. Per-iteration progress to stderr.
#
# Env knobs:
#   BURST_SEC         default 5    (cold-start window; 0 to skip)
#   WARMUP_SEC        default depends on CHASSIS_CLASS:
#                       fanless          → 60s
#                       active-cooled-pro → 300s (16" saturation is 5–8 min)
#                       desktop          → 180s
#   ITERATIONS        default 5
#   SECONDS_PER_ITER  default 60
#   WORKERS           default = P-cores
#   CHASSIS_CLASS     default active-cooled-pro

set -euo pipefail

CHASSIS_CLASS=${CHASSIS_CLASS:-active-cooled-pro}

case "$CHASSIS_CLASS" in
  fanless)            DEFAULT_WARMUP=60 ;;
  active-cooled-pro)  DEFAULT_WARMUP=300 ;;
  desktop)            DEFAULT_WARMUP=180 ;;
  intel-laptop)       DEFAULT_WARMUP=180 ;;  # Intel laptops saturate fast
  intel-desktop)      DEFAULT_WARMUP=180 ;;
  *)
    echo "cpu-variance.sh: unknown CHASSIS_CLASS='$CHASSIS_CLASS'" >&2
    echo "  use one of: fanless | active-cooled-pro | desktop | intel-laptop | intel-desktop" >&2
    exit 2
    ;;
esac

BURST_SEC=${BURST_SEC:-5}
WARMUP_SEC=${WARMUP_SEC:-$DEFAULT_WARMUP}
ITERATIONS=${ITERATIONS:-5}
SECONDS_PER_ITER=${SECONDS_PER_ITER:-60}

# WORKERS: probe P-cores then fall back; treat empty string as unset.
if [[ -z "${WORKERS:-}" ]]; then
  WORKERS=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null \
            || sysctl -n hw.physicalcpu 2>/dev/null \
            || sysctl -n hw.ncpu 2>/dev/null \
            || echo "")
fi
if ! [[ "$WORKERS" =~ ^[0-9]+$ ]] || (( WORKERS < 1 )); then
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

# macOS Python defaults to "spawn" which re-imports the script — fails for stdin.
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
    aggregate_throughput = total_mb / elapsed if elapsed > 0 else 0.0
    min_worker_mb = min(ops_list) if ops_list else 0
    max_worker_mb = max(ops_list) if ops_list else 0
    return aggregate_throughput, total_mb, elapsed, ops_list, min_worker_mb, max_worker_mb

# ---- 1) Cold-start burst ----
burst_throughput = None
if BURST_SEC > 0:
    print(f"  burst: {BURST_SEC}s cold-start measurement…", file=sys.stderr)
    burst_throughput, burst_mb, burst_elapsed, _, _, _ = run_window(BURST_SEC)
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
        last_chunk_throughput, _, _, _, _, _ = run_window(sec)
        remaining -= sec
    warmup_tail_throughput = last_chunk_throughput
    print(f"  warmup done (tail = {warmup_tail_throughput:,.0f} MB/s — discarded for spread)",
          file=sys.stderr)

# ---- 3) Timed iterations ----
throughputs = []          # aggregate MB/s per iter
worker_minmax_per_iter = []  # (min_worker_mb, max_worker_mb) per iter
worker_imbalance_pct_per_iter = []  # within-iter (max-min)/max × 100
for i in range(ITERATIONS):
    tput, total_mb, elapsed, ops_list, min_w, max_w = run_window(SECONDS_PER_ITER)
    throughputs.append(tput)
    worker_minmax_per_iter.append([min_w, max_w])
    imbalance = round((max_w - min_w) / max_w * 100, 2) if max_w > 0 else 0
    worker_imbalance_pct_per_iter.append(imbalance)
    print(f"  iter {i+1}/{ITERATIONS}: {total_mb:,} MB in {elapsed:.2f}s = {tput:,.0f} MB/s "
          f"(worker imbalance: {imbalance:.1f}%)",
          file=sys.stderr)

# ---- 4) Statistics ----
mean = statistics.mean(throughputs)
stdev = statistics.stdev(throughputs) if len(throughputs) > 1 else 0.0

# Dead-worker safeguard: if any iteration had a zero-throughput aggregate
# (worker died, OS killed it, etc.), the "ratio = 1.0" fallback would silently
# pass a defective unit. Surface it as a fail.
dead_worker_iter = None
for i, t in enumerate(throughputs):
    if t == 0:
        dead_worker_iter = i + 1
        break

spread_pct = (max(throughputs) - min(throughputs)) / mean * 100 if mean else 0
ratio_max  = max(throughputs) / min(throughputs) if min(throughputs) > 0 else float("inf")

# Trend: early-half mean vs late-half mean. A monotonic decline is the
# signature of a hot spot reaching threshold mid-test that spread can miss.
decline_pct = None
if len(throughputs) >= 4:
    half = len(throughputs) // 2
    early = statistics.mean(throughputs[:half])
    late = statistics.mean(throughputs[half:])
    decline_pct = round((early - late) / early * 100, 3) if early else None

# Burst-to-steady ratio: ADVISORY. Without crowd-sourced calibration baseline
# this is hard to interpret — record it for the agent / aggregator to judge.
burst_to_steady_ratio = None
if burst_throughput and burst_throughput > 0:
    burst_to_steady_ratio = round(mean / burst_throughput, 4)

# Within-iter worker imbalance — a single defective P-core would consistently
# under-perform if the macOS scheduler happens to pin a worker to it. Healthy
# units show < 5% median imbalance; > 10% suggests one worker (and possibly
# one core) is consistently behind.
median_worker_imbalance_pct = (
    round(statistics.median(worker_imbalance_pct_per_iter), 2)
    if worker_imbalance_pct_per_iter else None
)
max_worker_imbalance_pct = (
    round(max(worker_imbalance_pct_per_iter), 2)
    if worker_imbalance_pct_per_iter else None
)

# ---- 5) Verdict (escalates compound warnings to fail) ----
fail_signals = []
warn_signals = []
info_signals = []

if dead_worker_iter is not None:
    fail_signals.append(
        f"iteration {dead_worker_iter} had zero throughput (worker died) — verdict cannot be trusted"
    )

# Spread
if spread_pct > 10:
    fail_signals.append(f"spread {spread_pct:.1f}% > 10%")
elif spread_pct > 5:
    warn_signals.append(f"spread {spread_pct:.1f}% in 5–10% warn range")

# Max-to-min ratio (with explicit warn band)
if ratio_max == float("inf"):
    fail_signals.append("min throughput is 0 — cannot compute ratio")
elif ratio_max >= 1.4:
    fail_signals.append(f"max-to-min ratio {ratio_max:.2f}× ≥ 1.4×")
elif ratio_max >= 1.2:
    warn_signals.append(f"max-to-min ratio {ratio_max:.2f}× in 1.2–1.4× warn range")

# Decline (only meaningful with 4+ iterations)
if decline_pct is not None:
    if decline_pct > 10:
        fail_signals.append(f"throughput declined {decline_pct:.1f}% from early to late iterations")
    elif decline_pct > 5:
        warn_signals.append(f"throughput declined {decline_pct:.1f}% in 5–10% warn range")

# Burst-to-steady ratio — recorded as info, agent / aggregator interprets.
if burst_to_steady_ratio is not None and burst_to_steady_ratio > 0.97:
    info_signals.append(
        f"burst-to-steady {burst_to_steady_ratio:.2f}× — chassis gives back almost no thermal "
        f"headroom from cold; could indicate always-throttled unit, or just very strong cooling. "
        f"Compare against calibration baseline."
    )

# Worker imbalance — partial mitigation for the no-CPU-pinning gap. macOS
# schedules around a slow core, but if one worker is consistently 10%+ behind
# even after that, surface it.
if max_worker_imbalance_pct is not None:
    if max_worker_imbalance_pct > 20:
        fail_signals.append(
            f"max within-iter worker imbalance {max_worker_imbalance_pct:.1f}% — "
            f"one worker consistently behind by > 20%, possible single-core defect"
        )
    elif max_worker_imbalance_pct > 10:
        warn_signals.append(
            f"max within-iter worker imbalance {max_worker_imbalance_pct:.1f}% — "
            f"one worker behind by > 10%; rerun to confirm"
        )

# Compound-warn escalation: two or more independent warns = effective fail.
verdict = "pass"
if fail_signals:
    verdict = "fail"
elif len(warn_signals) >= 2:
    verdict = "fail"
    fail_signals.append(
        f"compound warning ({len(warn_signals)} independent warn signals) — escalated to fail"
    )
elif warn_signals:
    verdict = "warn"

reasons = fail_signals + warn_signals + info_signals
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
    "min_mb_per_s": round(min(throughputs), 1) if throughputs else None,
    "max_mb_per_s": round(max(throughputs), 1) if throughputs else None,
    "mean_mb_per_s": round(mean, 1),
    "stdev_mb_per_s": round(stdev, 1),
    "spread_pct": round(spread_pct, 3),
    "max_to_min_ratio": (
        round(ratio_max, 3) if ratio_max != float("inf") else None
    ),
    "early_vs_late_decline_pct": decline_pct,
    "burst_to_steady_ratio": burst_to_steady_ratio,
    "worker_imbalance_pct_per_iter": worker_imbalance_pct_per_iter,
    "median_worker_imbalance_pct": median_worker_imbalance_pct,
    "max_worker_imbalance_pct": max_worker_imbalance_pct,
    "verdict": verdict,
    "verdict_reasons": reasons,
    "workload": "sha256-parallel (hardware-accelerated on Apple Silicon — see script header CAVEAT)",
}
print(json.dumps(result, indent=2))
PYEOF
