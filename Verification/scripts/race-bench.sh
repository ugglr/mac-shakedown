#!/bin/bash
# race-bench.sh: fixed-work CPU race benchmark.
#
# Compresses a 200 MB incompressible-random blob with xz -9 -T<P-cores>, measures
# wall-clock seconds and throughput. Unlike cpu-variance.sh (SHA-256, hardware-
# accelerated on Apple Silicon), xz/LZMA is a general-purpose CPU workload that
# does not benefit from SHA-NI or the AMX/crypto coprocessor. The number is
# therefore comparable across chassis families (Apple Silicon vs Intel).
#
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   BLOB_MB    default 200  (size of random blob to compress)
#   PRESET     default 9    (xz compression level, 0-9; 9 = slow/strong)
#   THREADS    default = P-cores

set -euo pipefail

BLOB_MB=${BLOB_MB:-200}
PRESET=${PRESET:-9}

# THREADS: probe P-cores then fall back; treat empty string as unset.
if [[ -z "${THREADS:-}" ]]; then
  THREADS=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null \
            || sysctl -n hw.physicalcpu 2>/dev/null \
            || sysctl -n hw.ncpu 2>/dev/null \
            || echo "")
fi
if ! [[ "$THREADS" =~ ^[0-9]+$ ]] || (( THREADS < 1 )); then
  echo "race-bench.sh: could not determine thread count (sysctl failed)" >&2
  exit 2
fi

# xz ships in macOS since Catalina (10.15). Guard anyway.
if ! command -v xz >/dev/null 2>&1; then
  python3 - <<'PYEOF'
import json
print(json.dumps({
    "workload": "xz -T<P-cores> compression race",
    "verdict": "skipped",
    "data_quality": "skipped",
    "data_quality_notes": ["xz not found on PATH (race benchmark needs xz; ships with Catalina and later)"],
    "verdict_reasons": ["xz unavailable; phase skipped"],
}, indent=2))
PYEOF
  exit 0
fi

echo "race-bench: ${BLOB_MB}MB random blob, xz -${PRESET} -T${THREADS}" >&2

BLOB=$(mktemp -t shakedown-race.XXXXXX)
OUTPUT=$(mktemp -t shakedown-race-out.XXXXXX)
trap 'rm -f "$BLOB" "$OUTPUT"' EXIT INT TERM

python3 - "$BLOB" "$OUTPUT" "$BLOB_MB" "$PRESET" "$THREADS" <<'PYEOF'
import json
import os
import subprocess
import sys
import time

blob_path   = sys.argv[1]
output_path = sys.argv[2]
blob_mb     = int(sys.argv[3])
preset      = int(sys.argv[4])
threads     = int(sys.argv[5])

# Generate incompressible random blob. Must be fresh urandom per chunk: LZMA
# detects identical repeated blocks and compresses them ~10× tighter, which
# would defeat the "non-accelerated CPU-bound workload" property of this test.
# Blob generation is outside the timed region below, so the extra urandom cost
# does not affect the benchmark.
with open(blob_path, "wb") as f:
    for _ in range(blob_mb):
        f.write(os.urandom(1024 * 1024))
input_bytes = os.path.getsize(blob_path)

print(f"  generated {blob_mb}MB random data; starting xz...", file=sys.stderr)

# Time the compression. perf_counter rather than /usr/bin/time -p avoids
# format-parsing edge cases (BSD vs GNU output ordering).
with open(output_path, "wb") as out:
    t = time.perf_counter()
    proc = subprocess.run(
        ["xz", "-c", f"-{preset}", f"-T{threads}", blob_path],
        stdout=out, stderr=subprocess.PIPE,
    )
    wall = time.perf_counter() - t

if proc.returncode != 0:
    err = proc.stderr.decode("utf-8", errors="replace")[:500]
    print(json.dumps({
        "workload": f"xz -{preset} -T{threads} compression of {blob_mb}MB random data",
        "blob_size_mb": blob_mb,
        "threads": threads,
        "preset": preset,
        "verdict": "skipped",
        "data_quality": "skipped",
        "data_quality_notes": [f"xz exited rc={proc.returncode}", err],
        "verdict_reasons": ["xz failed; phase skipped"],
    }, indent=2))
    sys.exit(0)

output_bytes = os.path.getsize(output_path)
mb_per_s = (input_bytes / (1024 * 1024)) / wall if wall > 0 else 0
ratio = output_bytes / input_bytes if input_bytes else None

result = {
    "workload": f"xz -{preset} -T{threads} compression of {blob_mb}MB random data",
    "blob_size_mb": blob_mb,
    "threads": threads,
    "preset": preset,
    "wall_seconds": round(wall, 3),
    "input_bytes": input_bytes,
    "output_bytes": output_bytes,
    "compression_ratio": round(ratio, 4) if ratio is not None else None,
    "throughput_mb_per_s": round(mb_per_s, 2),
    "data_quality": "ok",
    "data_quality_notes": [],
    "verdict": "info",
    "verdict_reasons": [
        f"compressed {blob_mb}MB in {wall:.2f}s ({mb_per_s:.1f} MB/s, "
        f"output {ratio*100:.1f}% of input)" if ratio is not None
        else f"compressed {blob_mb}MB in {wall:.2f}s ({mb_per_s:.1f} MB/s)",
        "informational in v0.2; calibrated pass/fail thresholds land in v0.3"
    ],
}
print(json.dumps(result, indent=2))
PYEOF
