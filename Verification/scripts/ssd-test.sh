#!/bin/bash
# ssd-test.sh: sequential SSD write+read benchmark.
#
# Writes SIZE_GB of incompressible random data to a temp file, runs `sudo purge`
# to drop the page cache, reads it back. Reports write and read throughput.
#
# Incompressible random data matters because APFS transparently compresses
# zeros (a `dd if=/dev/zero` write would report fictional GB/s). Page-cache
# drop matters because without it the read is RAM speed, not SSD.
#
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   SIZE_GB         default 2   (test file size; needs 2× free space headroom)
#   ALLOW_NO_PURGE  default 0   (if 1, skip sudo purge; read numbers will
#                                include page cache and be unrealistically high)

set -euo pipefail

SIZE_GB=${SIZE_GB:-2}
ALLOW_NO_PURGE=${ALLOW_NO_PURGE:-0}

if ! [[ "$SIZE_GB" =~ ^[0-9]+$ ]] || (( SIZE_GB < 1 )); then
  echo "ssd-test.sh: SIZE_GB must be a positive integer (got '$SIZE_GB')" >&2
  exit 2
fi

# Free-space safety: require 2× the test size on the volume holding the temp dir.
# df -g reports in GB (1024^3) on macOS; column 4 is "available".
FREE_GB=$(df -g . 2>/dev/null | awk 'NR==2 {print $4}')
NEEDED_GB=$((SIZE_GB * 2))
if ! [[ "$FREE_GB" =~ ^[0-9]+$ ]] || (( FREE_GB < NEEDED_GB )); then
  python3 - "$FREE_GB" "$NEEDED_GB" "$SIZE_GB" <<'PYEOF'
import json, sys
free, needed, size_gb = sys.argv[1], sys.argv[2], int(sys.argv[3])
print(json.dumps({
    "workload": f"sequential write+read of {size_gb}GB",
    "size_gb": size_gb,
    "verdict": "skipped",
    "data_quality": "skipped",
    "data_quality_notes": [
        f"insufficient free space: {free or 'unknown'} GB available, "
        f"need {needed} GB (2× test size headroom)"
    ],
    "verdict_reasons": ["insufficient free space; phase skipped"],
}, indent=2))
PYEOF
  exit 0
fi

TEMP_DIR=$(mktemp -d -t shakedown-ssd)
trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

TEST_FILE="$TEMP_DIR/test.bin"

echo "ssd-test: writing ${SIZE_GB}GB incompressible random data" >&2

python3 - "$TEST_FILE" "$SIZE_GB" "$ALLOW_NO_PURGE" <<'PYEOF'
import json
import os
import subprocess
import sys
import time

test_file      = sys.argv[1]
size_gb        = int(sys.argv[2])
allow_no_purge = sys.argv[3] == "1"

# Reuse a single random 8 MB chunk across writes. Generating fresh urandom for
# every chunk costs measurable time and isn't needed: APFS deduplication does
# not look across writes to a single growing file, and compression sees blocks
# individually. One incompressible 8 MB chunk repeated is plenty.
CHUNK_MB = 8
chunk = os.urandom(CHUNK_MB * 1024 * 1024)
chunks = (size_gb * 1024) // CHUNK_MB
total_bytes = chunks * CHUNK_MB * 1024 * 1024

data_quality_notes = []

# --- Write benchmark ---
t = time.perf_counter()
with open(test_file, "wb") as f:
    for _ in range(chunks):
        f.write(chunk)
    f.flush()
    os.fsync(f.fileno())
write_seconds = time.perf_counter() - t
write_mb_per_s = (total_bytes / (1024 * 1024)) / write_seconds if write_seconds > 0 else 0

print(f"  wrote {total_bytes // (1024*1024)}MB in {write_seconds:.2f}s "
      f"= {write_mb_per_s:.0f} MB/s", file=sys.stderr)

# --- Drop page cache so the read measures SSD, not RAM ---
purge_ok = False
if allow_no_purge:
    data_quality_notes.append(
        "ALLOW_NO_PURGE=1 set; page cache not dropped, so read numbers will "
        "reflect RAM speed instead of SSD speed"
    )
else:
    print("  dropping page cache (sudo purge)...", file=sys.stderr)
    try:
        subprocess.run(["sudo", "-n", "/usr/sbin/purge"],
                       check=True, timeout=60)
        purge_ok = True
    except FileNotFoundError:
        data_quality_notes.append(
            "/usr/sbin/purge not found; page cache not dropped, so read "
            "numbers will include cache and be artificially high"
        )
    except subprocess.TimeoutExpired:
        data_quality_notes.append(
            "sudo purge timed out after 60s; page cache likely not fully "
            "dropped, so read numbers may be inflated"
        )
    except subprocess.CalledProcessError as e:
        data_quality_notes.append(
            f"sudo purge failed (rc={e.returncode}; sudo session may have "
            f"expired), so read numbers will include page cache"
        )

# --- Read benchmark ---
t = time.perf_counter()
bytes_read = 0
with open(test_file, "rb") as f:
    while True:
        buf = f.read(CHUNK_MB * 1024 * 1024)
        if not buf:
            break
        bytes_read += len(buf)
read_seconds = time.perf_counter() - t
read_mb_per_s = (bytes_read / (1024 * 1024)) / read_seconds if read_seconds > 0 else 0

print(f"  read {bytes_read // (1024*1024)}MB in {read_seconds:.2f}s "
      f"= {read_mb_per_s:.0f} MB/s "
      f"({'cache dropped' if purge_ok else 'CACHE NOT DROPPED'})",
      file=sys.stderr)

# --- Verdict & data quality ---
# v0.2: SSD numbers are informational. They contribute to calibration but don't
# pass/fail on their own until v0.3 sets chassis-family thresholds.
data_quality = "ok" if purge_ok else "few_samples"

result = {
    "workload": f"sequential write+read of {size_gb}GB incompressible random data",
    "size_gb": size_gb,
    "chunk_mb": CHUNK_MB,
    "write_seconds": round(write_seconds, 3),
    "write_mb_per_s": round(write_mb_per_s, 2),
    "page_cache_dropped": purge_ok,
    "read_seconds": round(read_seconds, 3),
    "read_mb_per_s": round(read_mb_per_s, 2),
    "data_quality": data_quality,
    "data_quality_notes": data_quality_notes,
    "verdict": "info",
    "verdict_reasons": [
        f"write {write_mb_per_s:.0f} MB/s, read {read_mb_per_s:.0f} MB/s"
        + ("" if purge_ok else " (cache not dropped, so read is RAM speed)"),
        "informational in v0.2; calibrated pass/fail thresholds land in v0.3"
    ],
}
print(json.dumps(result, indent=2))
PYEOF
