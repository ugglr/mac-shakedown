#!/bin/bash
# gpu-variance.sh: GPU sustained-compute variance (Metal).
#
# OPT-IN phase (./run --gpu). Unlike every other phase, this one is not pure
# bash + Python stdlib: a real GPU compute load needs a GPU kernel. It compiles
# a small, readable Metal compute kernel with `swiftc` AT RUNTIME (no binary is
# shipped in the repo) and runs sustained FMA work, measuring per-iteration
# throughput the same way cpu-variance.sh does. The GPU is the bigger thermal
# contributor on Apple Silicon, so a Metal load is more aggressive than CPU
# SHA-256 and surfaces GPU-side batch variance.
#
# It degrades gracefully to a "skipped" verdict (never fails the run) when:
#   - swiftc is not installed (no Xcode / Command Line Tools Swift toolchain)
#   - the Metal source fails to compile
#   - no Metal device is available (headless / SSH session / older Intel Mac
#     without a usable GPU context)
#
# The Swift source is right here in the heredoc below: read it before you run.
#
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   GPU_ITERS     default 5   (timed iterations, for run-to-run variance)
#   GPU_SECONDS   default 3   (seconds per timed iteration)

set -euo pipefail

GPU_ITERS=${GPU_ITERS:-5}
GPU_SECONDS=${GPU_SECONDS:-3}

for v in GPU_ITERS GPU_SECONDS; do
  if ! [[ "${!v}" =~ ^[0-9]+$ ]] || (( ${!v} < 1 )); then
    echo "gpu-variance.sh: $v must be a positive integer (got '${!v}')" >&2
    exit 2
  fi
done

emit_skipped() {
  # $1: human-readable reason. Routed through python3 so the JSON is well-formed.
  python3 - "$1" <<'PYEOF'
import json
import sys
reason = sys.argv[1]
print(json.dumps({
    "workload": "metal-compute fma burn (GPU sustained FP throughput variance)",
    "verdict": "skipped",
    "data_quality": "skipped",
    "data_quality_notes": [reason],
    "verdict_reasons": [reason + "; phase skipped"],
}, indent=2))
PYEOF
}

if ! command -v swiftc >/dev/null 2>&1; then
  emit_skipped "swiftc not found (GPU phase needs the Swift toolchain from Xcode or Command Line Tools)"
  exit 0
fi

GPU_TMP=$(mktemp -d -t shakedown-gpu)
trap 'rm -rf "$GPU_TMP"' EXIT INT TERM
SWIFT_SRC="$GPU_TMP/burn.swift"
BIN="$GPU_TMP/burn"
RAW_JSON="$GPU_TMP/raw.json"

cat > "$SWIFT_SRC" <<'SWIFTEOF'
import Metal
import Foundation

func bail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(3)
}

let args = CommandLine.arguments
let iterations = args.count > 1 ? (Int(args[1]) ?? 5) : 5
let secondsPerIter = args.count > 2 ? (Double(args[2]) ?? 3.0) : 3.0

guard let dev = MTLCreateSystemDefaultDevice() else {
    bail("NO_METAL_DEVICE: MTLCreateSystemDefaultDevice returned nil")
}
guard let queue = dev.makeCommandQueue() else { bail("NO_METAL_QUEUE: makeCommandQueue failed") }

let kernelSrc = """
#include <metal_stdlib>
using namespace metal;
kernel void burn(device float* buf [[buffer(0)]],
                 constant uint& inner [[buffer(1)]],
                 uint gid [[thread_position_in_grid]]) {
    float x = buf[gid];
    for (uint k = 0u; k < inner; k++) {
        x = fma(x, 1.0000001f, 0.0000001f);
    }
    buf[gid] = x;
}
"""

let pipe: MTLComputePipelineState
do {
    let lib = try dev.makeLibrary(source: kernelSrc, options: nil)
    guard let fn = lib.makeFunction(name: "burn") else { bail("NO_KERNEL_FN") }
    pipe = try dev.makeComputePipelineState(function: fn)
} catch {
    bail("PIPELINE_FAIL: \(error)")
}

let requested = 1 << 20
let tgSize = min(pipe.maxTotalThreadsPerThreadgroup, 256)
let groups = max(1, requested / tgSize)
let threadsTotal = groups * tgSize
let inner: UInt32 = 4096
var innerVar = inner

guard let buf = dev.makeBuffer(length: threadsTotal * MemoryLayout<Float>.stride,
                               options: .storageModeShared) else { bail("NO_BUFFER") }

func dispatchOnce() {
    guard let cmd = queue.makeCommandBuffer(),
          let enc = cmd.makeComputeCommandEncoder() else { bail("NO_ENCODER") }
    enc.setComputePipelineState(pipe)
    enc.setBuffer(buf, offset: 0, index: 0)
    enc.setBytes(&innerVar, length: MemoryLayout<UInt32>.size, index: 1)
    enc.dispatchThreadgroups(MTLSize(width: groups, height: 1, depth: 1),
                             threadsPerThreadgroup: MTLSize(width: tgSize, height: 1, depth: 1))
    enc.endEncoding()
    cmd.commit()
    cmd.waitUntilCompleted()
}

dispatchOnce()  // warm: compile pipeline caches, first-launch transient

var perIter: [Double] = []
for _ in 0..<iterations {
    var dispatches = 0
    let start = Date()
    while Date().timeIntervalSince(start) < secondsPerIter {
        dispatchOnce()
        dispatches += 1
    }
    let elapsed = Date().timeIntervalSince(start)
    // Each thread does `inner` FMAs; an FMA counts as 2 flops (multiply + add).
    let flops = Double(dispatches) * Double(threadsTotal) * Double(inner) * 2.0
    let gflops = elapsed > 0 ? flops / elapsed / 1e9 : 0.0
    perIter.append(gflops)
    FileHandle.standardError.write(
        String(format: "  iter: %.1f GFLOP/s (%d dispatches)\n", gflops, dispatches)
            .data(using: .utf8)!)
}

let name = dev.name
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
let arr = perIter.map { String(format: "%.3f", $0) }.joined(separator: ", ")
print("{")
print("  \"device\": \"\(name)\",")
print("  \"low_power\": \(dev.isLowPower),")
print("  \"iterations\": \(iterations),")
print("  \"seconds_per_iter\": \(secondsPerIter),")
print("  \"threads_per_dispatch\": \(threadsTotal),")
print("  \"fma_iters_per_thread\": \(inner),")
print("  \"throughput_gflops\": [\(arr)]")
print("}")
SWIFTEOF

echo "gpu-variance: compiling Metal kernel with swiftc (one-time, ~10s)..." >&2
if ! swiftc -O "$SWIFT_SRC" -o "$BIN" 2>"$GPU_TMP/compile.err"; then
  emit_skipped "Metal source failed to compile: $(tr '\n' ' ' < "$GPU_TMP/compile.err" | cut -c1-300)"
  exit 0
fi

echo "gpu-variance: running $GPU_ITERS x ${GPU_SECONDS}s GPU compute..." >&2
T0=$(date +%s)
RUN_RC=0
"$BIN" "$GPU_ITERS" "$GPU_SECONDS" > "$RAW_JSON" 2>"$GPU_TMP/run.err" || RUN_RC=$?
T1=$(date +%s)

if [[ "$RUN_RC" -ne 0 ]]; then
  emit_skipped "GPU run did not complete (rc=$RUN_RC): $(tr '\n' ' ' < "$GPU_TMP/run.err" | cut -c1-200)"
  exit 0
fi

python3 - "$RAW_JSON" "$((T1 - T0))" <<'PYEOF'
import json
import statistics
import sys

with open(sys.argv[1]) as f:
    raw = json.load(f)
wall = int(sys.argv[2])

tg = raw.get("throughput_gflops") or []
if not tg:
    print(json.dumps({
        "workload": "metal-compute fma burn (GPU sustained FP throughput variance)",
        "device": raw.get("device"),
        "verdict": "skipped",
        "data_quality": "skipped",
        "data_quality_notes": ["GPU produced no throughput samples"],
        "verdict_reasons": ["no GPU throughput samples; phase skipped"],
    }, indent=2))
    sys.exit(0)

mean = statistics.mean(tg)
mn = min(tg)
mx = max(tg)
spread_pct = round((mx - mn) / mean * 100, 3) if mean else 0.0
ratio = round(mx / mn, 3) if mn > 0 else None

decline_pct = None
if len(tg) >= 4:
    half = len(tg) // 2
    early = statistics.mean(tg[:half])
    late = statistics.mean(tg[half:])
    decline_pct = round((early - late) / early * 100, 3) if early else None

result = {
    "workload": "metal-compute fma burn (GPU sustained FP throughput variance)",
    "device": raw.get("device"),
    "low_power": raw.get("low_power"),
    "iterations": raw.get("iterations"),
    "seconds_per_iter": raw.get("seconds_per_iter"),
    "threads_per_dispatch": raw.get("threads_per_dispatch"),
    "fma_iters_per_thread": raw.get("fma_iters_per_thread"),
    "throughput_gflops": tg,
    "mean_gflops": round(mean, 2),
    "min_gflops": round(mn, 2),
    "max_gflops": round(mx, 2),
    "spread_pct": spread_pct,
    "max_to_min_ratio": ratio,
    "early_vs_late_decline_pct": decline_pct,
    "wall_seconds": wall,
    "data_quality": "ok",
    "data_quality_notes": [],
    "verdict": "info",
    "verdict_reasons": [
        f"{raw.get('device')}: mean {mean:,.0f} GFLOP/s, spread {spread_pct:.1f}%"
        + (f", ratio {ratio:.2f}x" if ratio is not None else ""),
        "informational in v0.2; GPU variance thresholds land once the corpus has baselines"
    ],
}
print(json.dumps(result, indent=2))
PYEOF
