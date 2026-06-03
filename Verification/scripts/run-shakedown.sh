#!/bin/bash
# run-shakedown.sh: orchestrator: runs the auto-runnable phases end-to-end and
# writes two JSON reports: a full local copy and a sanitized submission copy.
#
# Usage:
#   ./Verification/scripts/run-shakedown.sh --target mbp-16-m5-max-64
#
# Writes:
#   Reports/local/<filename>.json      , full output, gitignored (keeps _raw_* fields)
#   Reports/submissions/<filename>.json, sanitized, committable as a PR
#
# Phases 6 (display), 7 (physical), 8 (Apple Diagnostics), 9 (idle drain) emit
# `verdict: "skipped"` placeholders, friend hand-edits the local copy if they
# ran any of those, then re-runs the sanitize step or copies the result.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET=""
NOTES=""
NO_SUDO=0
RUN_NOACCEL=0
RUN_GPU=0
STORE=0
RUN_LLAMA=0
STRICT=0

ARGC=$#
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --notes)
      NOTES="${2:-}"
      shift 2
      ;;
    --no-sudo|--skip-thermal)
      NO_SUDO=1
      shift
      ;;
    --noaccel)
      RUN_NOACCEL=1
      shift
      ;;
    --gpu)
      RUN_GPU=1
      shift
      ;;
    --store)
      STORE=1
      shift
      ;;
    --llama)
      RUN_LLAMA=1
      shift
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      cat <<HELP
Usage: $(basename "$0") [--target <preset>] [--store] [--strict] [--no-sudo] [--noaccel] [--gpu] [--llama] [--notes "free-form notes"]

  --target <preset>   optional. Target preset name (file under targets/ without .json)
                      e.g. mbp-16-m5-max-64, macbook-air-m5-16, mbp-16-intel-2019.
                      If omitted, the matching preset is auto-selected from the
                      detected hardware (chip, memory, model), so you usually do
                      not need it. Pass it to assert an expected SKU, or to
                      override the match. If nothing matches, asserts are skipped.
  --no-sudo           skip Phase 5 (sustained thermal load), the only phase that
                      needs sudo. Phase 4 (variance) still runs and is the headline
                      test. Alias: --skip-thermal.
  --noaccel           also run Phase 4b: a second variance pass on a non-accelerated
                      workload (BLAKE2b) that stresses the integer pipelines SHA-NI
                      hides. Opt-in because it adds a second sustained pass.
  --gpu               also run Phase 13: a Metal GPU compute variance pass. Compiles
                      a small Metal kernel with swiftc at runtime; skips cleanly if
                      swiftc or a Metal device is unavailable.
  --llama             also run Phase 14: an opt-in combined CPU+GPU+memory load.
                      Clones and builds llama.cpp (needs git + cmake + network)
                      and runs llama-bench. Reaches the network and runs
                      third-party code (see SECURITY.md). Skips cleanly if any of
                      git / cmake / network / model is unavailable.
  --store             thorough "paranoid" profile for verifying a new unit (M5
                      especially). Turns on --noaccel and --gpu and runs a longer
                      warmup with more iterations, so an intermittent batch defect
                      has more chances to surface. ~40-50 min on AC. Honors any
                      WARMUP_SEC / ITERATIONS / SECONDS_PER_ITER you set yourself.
  --strict            production / calibration mode: refuse to score a run taken
                      under non-comparable conditions. Checks the preconditions
                      that are only warnings by default (on AC, quiet system)
                      before the load phases and aborts if they fail, so you do
                      not burn 45 minutes on a number you would have to discard.
  --notes "..."       optional free-form note to embed in the report. Setting any
                      note flips submission_safe to false (notes may contain PII).

Chassis class: read from the preset when one is given or auto-selected;
otherwise auto-detected from system_profiler (override with CHASSIS_CLASS env var).
HELP
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# Interactive picker: with no flags on a terminal, ask a couple of questions and
# build the run instead of making the user remember flags. Any explicit flag, a
# non-interactive stdin (pipe / CI), or SHAKEDOWN_YES=1 skips it, so scripted and
# flag-driven use is unchanged. Sets the same variables the flags would.
interactive_picker() {
  local sku choice ans built
  sku=$(python3 - <<'PYEOF' 2>/dev/null
import json
import subprocess
try:
    hw = json.loads(subprocess.check_output(
        ["system_profiler", "-json", "SPHardwareDataType"],
        stderr=subprocess.DEVNULL))["SPHardwareDataType"][0]
    chip = hw.get("chip_type") or hw.get("cpu_type") or "Mac"
except Exception:
    chip = "this Mac"
try:
    mem = round(int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).decode()) / (1024 ** 3))
    print(f"{chip}, {mem} GB")
except Exception:
    print(chip)
PYEOF
)
  {
    echo ""
    echo "shakedown: detected ${sku:-this Mac}"
    echo ""
    echo "  What are you doing?"
    echo "    1) Verify a new Mac   thorough, ~45 min"
    echo "    2) Quick check        ~20 min"
    echo "    3) Custom / show flags"
  } >&2
  read -r -p "  > " choice || true
  case "$choice" in
    1)
      STORE=1
      read -r -p "  Refuse to score unless on AC and idle? [Y/n] " ans || true
      if [[ ! "$ans" =~ ^[Nn] ]]; then STRICT=1; fi
      read -r -p "  Also run the AI/LLM load? (builds llama.cpp, needs network, adds time) [y/N] " ans || true
      if [[ "$ans" =~ ^[Yy] ]]; then RUN_LLAMA=1; fi
      ;;
    2)
      : # default profile, no extra flags
      ;;
    3)
      echo "  Run '$(basename "$0") --help' for all flags, then re-run with the ones you want." >&2
      exit 0
      ;;
    *)
      echo "  Unrecognized choice; running the quick check." >&2
      ;;
  esac
  built="./run"
  if [[ "$STORE" -eq 1 ]]; then built+=" --store"; fi
  if [[ "$STRICT" -eq 1 ]]; then built+=" --strict"; fi
  if [[ "$RUN_LLAMA" -eq 1 ]]; then built+=" --llama"; fi
  {
    echo ""
    echo "  -> $built"
    echo "  Starting. Fans will get loud; it asks for your login password once."
  } >&2
  # The picker is the confirmation, so skip the second "Proceed?" prompt below.
  SHAKEDOWN_YES=1
}

if [[ "$ARGC" -eq 0 && -t 0 && "${SHAKEDOWN_YES:-0}" != "1" ]]; then
  interactive_picker
fi

export STRICT

# --store: thorough profile for verifying a new unit (especially M5). Run both CPU
# workloads (SHA-256 plus the non-accelerated BLAKE2b that matches where the M5
# defect was reported) and the GPU pass, with a longer warmup and more iterations
# so an intermittent batch defect has more chances to surface. The := assignments
# honor any timing env vars the user set explicitly. Exported so the cpu-variance
# child phases inherit them.
if [[ "$STORE" -eq 1 ]]; then
  RUN_NOACCEL=1
  RUN_GPU=1
  : "${WARMUP_SEC:=420}"
  : "${ITERATIONS:=8}"
  : "${SECONDS_PER_ITER:=60}"
  : "${NOACCEL_WARMUP_SEC:=180}"
  export WARMUP_SEC ITERATIONS SECONDS_PER_ITER NOACCEL_WARMUP_SEC
fi

TARGET_FILE=""

# Resolve the target preset and chassis class from the detected hardware. When the
# user gave neither --target nor a CHASSIS_CLASS override, match the machine (chip,
# memory, model family, and screen size) against the presets in targets/ and use the
# one that fits; this is the inverse of the inventory asserts and uses the same
# sources (chip_type / cpu_type, hw.memsize), so an auto-selected preset always
# passes its own asserts. One unambiguous match wins; zero or several leaves the
# preset empty. Either way we derive the chassis class so the thermal phase uses the
# right bands. Screen size (from the built-in display) separates the 14" (looser) and
# 16" (strict) MacBook Pro thermal sub-classes, because Apple Silicon does not put it
# in the model identifier. Pass --target to assert an expected SKU or to override.
if [[ -z "$TARGET" && -z "${CHASSIS_CLASS:-}" ]]; then
  _resolved=$(python3 - "$REPO_ROOT/targets" <<'PYEOF'
import glob
import json
import os
import re
import subprocess
import sys

def sysctl(key):
    try:
        return subprocess.check_output(["sysctl", "-n", key],
                                       stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return None

def builtin_screen_inches(displays):
    # Native built-in panel width -> size class: 14"/16" MacBook Pro, Intel 16".
    # Apple Silicon does not expose screen size in the model identifier, so the
    # 14"/16" thermal sub-class is read from the panel resolution instead.
    width_to_inches = {3024: 14, 3456: 16, 3072: 16}
    for gpu in displays:
        for nd in gpu.get("spdisplays_ndrvs", []):
            if nd.get("spdisplays_connection_type") != "spdisplays_internal":
                continue
            for field in ("spdisplays_pixelresolution", "_spdisplays_pixels"):
                m = re.search(r"(\d{3,4})\s*x\s*\d{3,4}", str(nd.get(field, "")))
                if m and int(m.group(1)) in width_to_inches:
                    return width_to_inches[int(m.group(1))]
    return None

try:
    sp = json.loads(subprocess.check_output(
        ["system_profiler", "-json", "SPHardwareDataType", "SPDisplaysDataType"],
        stderr=subprocess.DEVNULL))
    hw = sp["SPHardwareDataType"][0]
except Exception:
    print("\t")  # no detection: empty preset + empty chassis, caller errors out
    sys.exit(0)

chip = hw.get("chip_type") or hw.get("cpu_type") or ""
haystack = " ".join(filter(None, [hw.get("machine_model"), hw.get("machine_name")]))
is_apple_silicon = bool(hw.get("chip_type"))
is_laptop = "MacBook" in haystack
is_air = "Air" in haystack
screen = builtin_screen_inches(sp.get("SPDisplaysDataType", []))
memraw = sysctl("hw.memsize")
mem_gb = round(int(memraw) / (1024 ** 3)) if memraw and memraw.isdigit() else None

if is_apple_silicon:
    if is_laptop and is_air:
        chassis = "fanless"
    elif is_laptop:
        chassis = ("active-cooled-pro-14" if screen == 14 else
                   "active-cooled-pro-16" if screen == 16 else
                   "active-cooled-pro")
    else:
        chassis = "desktop"
else:
    chassis = "intel-laptop" if is_laptop else "intel-desktop"

matches = []
for path in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    try:
        with open(path) as f:
            t = json.load(f)
    except (OSError, ValueError):
        continue
    cp = t.get("chip_pattern")
    if not cp or cp not in chip:
        continue
    if t.get("memory_gb") is not None and t["memory_gb"] != mem_gb:
        continue
    mmi = t.get("model_must_include")
    if mmi and mmi not in haystack:
        continue
    si = t.get("screen_inches")
    # Screen gates only when the preset declares it AND we could read the panel,
    # so a unique-chip preset still matches when the display is unreadable.
    if si is not None and screen is not None and si != screen:
        continue
    matches.append(os.path.splitext(os.path.basename(path))[0])

target = matches[0] if len(matches) == 1 else ""
print(f"{target}\t{chassis}")
PYEOF
)
  TARGET="${_resolved%%$'\t'*}"
  _auto_chassis="${_resolved#*$'\t'}"
  [[ -n "$TARGET" ]] && echo "shakedown: auto-selected target '$TARGET' from detected hardware (pass --target to override)" >&2
fi

if [[ -n "$TARGET" ]]; then
  TARGET_FILE="$REPO_ROOT/targets/$TARGET.json"
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "run-shakedown.sh: target preset not found: $TARGET_FILE" >&2
    exit 2
  fi
  CHASSIS_CLASS=$(python3 - "$TARGET_FILE" <<'PYEOF'
import json
import sys
with open(sys.argv[1]) as f:
    d = json.load(f)
print(d.get("thermal_chassis_class", "active-cooled-pro"))
PYEOF
)
elif [[ -z "${CHASSIS_CLASS:-}" ]]; then
  # No preset matched and no override: use the chassis class derived from the
  # detected hardware above (screen size picks the 14"/16" MacBook Pro sub-class;
  # an unreadable panel leaves the generic active-cooled-pro, the strict default).
  CHASSIS_CLASS="${_auto_chassis:-}"
  if [[ -z "$CHASSIS_CLASS" ]]; then
    echo "run-shakedown.sh: could not auto-detect chassis class." >&2
    echo "  Set CHASSIS_CLASS env var explicitly:" >&2
    echo "  fanless | active-cooled-pro | desktop | intel-laptop | intel-desktop" >&2
    exit 2
  fi
fi
export CHASSIS_CLASS

ignite() {
  # Build-up flame animation before a phase. ~700 ms total, short enough that
  # it doesn't pad the run, long enough to give the eye a transition. Falls
  # back to a plain echo when stderr isn't a TTY (CI, piped logs).
  if [[ ! -t 2 ]]; then
    echo "shakedown: $*" >&2
    return
  fi
  local label="$*"
  local R=$'\033[91m'
  local B=$'\033[1;31m'
  local X=$'\033[0m'
  local cl=$'\r\033[K'
  local frames=('▁' '▂' '▃' '▄ ▁' '▅ ▂' '▆ ▃ ▁' '▇ ▄ ▂' '█ ▅ ▃ ▁' '▇ ▆ ▄ ▂' '█ ▇ ▅ ▃')
  for f in "${frames[@]}"; do
    printf '%s%s%s%s' "$cl" "$R" "$f" "$X" >&2
    sleep 0.07
  done
  printf '%s%s██  %s%s\n' "$cl" "$B" "$label" "$X" >&2
}

heartbeat() {
  # Background sparks during silent stretches (Phase 4 warmup, Phase 5 sustained
  # load). Sparse and varied, prints to stderr without \r so it doesn't fight
  # with the sub-script's own progress prints. Suppressed when not a TTY.
  if [[ ! -t 2 ]]; then return; fi
  local Y=$'\033[93m'
  local O=$'\033[33m'
  local R=$'\033[91m'
  local X=$'\033[0m'
  local sparks=(
    "${Y}    *   .  ✦${X}"
    "${O}  ·    *   ${X}"
    "${R}    ✦   ·  ${X}"
    "${Y}  ·   .  *  ${X}"
    "${O}    ·   ·   ${X}"
    "${R}   *  ✦    ·${X}"
    "${Y}  ✦   ·  *  ${X}"
    "${O}    ·     . ${X}"
  )
  local i=0
  while true; do
    sleep $(( 10 + RANDOM % 8 ))   # 10–17 seconds between sparks
    kill -0 "$$" 2>/dev/null || exit
    printf '  %s\n' "${sparks[i % ${#sparks[@]}]}" >&2
    i=$((i + 1))
  done
}

start_heartbeat() {
  if [[ ! -t 2 ]]; then return; fi
  heartbeat &
  HEARTBEAT_PID=$!
}

stop_heartbeat() {
  if [[ -n "${HEARTBEAT_PID:-}" ]]; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
    HEARTBEAT_PID=""
  fi
}

banner() {
  if [[ ! -t 2 ]]; then return; fi
  local Y=$'\033[93m'      # bright yellow (wisps)
  local O=$'\033[33m'      # yellow (mid)
  local R=$'\033[91m'      # bright red (base)
  local B=$'\033[1;31m'    # bold red (letters)
  local D=$'\033[2m'       # dim (subtitle)
  local X=$'\033[0m'       # reset
  cat >&2 <<BANNER

${Y}     )         )         )         )         )         )         )${X}
${Y}    ((        ((        ((        ((        ((        ((        ((${X}
${O}    ))(       ))(       ))(       ))(       ))(       ))(       ))(${X}
${R}   ((  ))    ((  ))    ((  ))    ((  ))    ((  ))    ((  ))    ((  ))${X}
${R}    \\\\//      \\\\//      \\\\//      \\\\//      \\\\//      \\\\//      \\\\//${X}

${B}███████ ██   ██  █████  ██   ██ ███████ ██████   ██████  ██     ██ ███    ██${X}
${B}██      ██   ██ ██   ██ ██  ██  ██      ██   ██ ██    ██ ██     ██ ████   ██${X}
${B}███████ ███████ ███████ █████   █████   ██   ██ ██    ██ ██  █  ██ ██ ██  ██${X}
${B}     ██ ██   ██ ██   ██ ██  ██  ██      ██   ██ ██    ██ ██ ███ ██ ██  ██ ██${X}
${B}███████ ██   ██ ██   ██ ██   ██ ███████ ██████   ██████   ███ ███  ██   ████${X}

${D}         verify your new Mac before the return window closes${X}

BANNER
}

banner

if [[ "$NO_SUDO" -eq 1 ]]; then
  echo "shakedown: target=${TARGET:-<none>} chassis_class=$CHASSIS_CLASS mode=--no-sudo (Phase 5 will be skipped)"
else
  echo "shakedown: target=${TARGET:-<none>} chassis_class=$CHASSIS_CLASS"
fi

if [[ -z "${SHAKEDOWN_YES:-}" ]]; then
  if [[ "$STORE" -eq 1 ]]; then
    duration_hint="STORE profile (thorough): both CPU workloads plus GPU, longer warmup and $ITERATIONS iterations, roughly 40-50 min total on AC"
  else
    duration_hint="race + SSD + memory benchmarks (~2 min), then Phase 4 variance (~8 min)"
    if [[ "$NO_SUDO" -ne 1 ]]; then duration_hint="$duration_hint, Phase 5 thermal (~10 min)"; fi
    if [[ "$RUN_NOACCEL" -eq 1 ]]; then duration_hint="$duration_hint, Phase 4b non-accelerated variance (~6 min)"; fi
    if [[ "$RUN_GPU" -eq 1 ]]; then duration_hint="$duration_hint, Phase 13 GPU compute (~1 min)"; fi
  fi
  if [[ "$RUN_LLAMA" -eq 1 ]]; then duration_hint="$duration_hint; plus Phase 14 llama.cpp (opt-in: clones + builds, can add 5-15 min on first run)"; fi
  cat <<INFO >&2

About to run $duration_hint. Fans will spin up loud and the chassis will get
hot. macOS throttles to protect the chip, so nothing dangerous, but expect a
noisy run.

Set SHAKEDOWN_YES=1 to skip this prompt (e.g. for scripted runs).
INFO
  read -r -p "Proceed? [y/N] " ans
  if [[ ! "$ans" =~ ^[Yy] ]]; then
    echo "shakedown: aborted before any load was run" >&2
    exit 1
  fi
fi

SUDO_KEEPALIVE_PID=""
if [[ "$NO_SUDO" -ne 1 ]]; then
  echo "shakedown: requesting sudo upfront (Phase 5 needs it)"
  sudo -v
  # Background keep-alive: refresh sudo credentials every 60s while the
  # orchestrator is alive. macOS default sudo timestamp is 5 min, and Phase 4
  # on Intel takes ~8 min, without this, the user gets a second password
  # prompt mid-run.
  ( while true; do
      sleep 60
      kill -0 "$$" 2>/dev/null || exit
      sudo -n true 2>/dev/null || exit
    done ) &
  SUDO_KEEPALIVE_PID=$!
fi

WORK=$(mktemp -d -t shakedown-run)
HEARTBEAT_PID=""
trap 'if [[ -n "$HEARTBEAT_PID" ]]; then kill "$HEARTBEAT_PID" 2>/dev/null || true; fi; if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; fi; rm -rf "$WORK"' EXIT

PREFLIGHT_TXT="$WORK/preflight.txt"
INVENTORY_JSON="$WORK/inventory.json"
BATTERY_JSON="$WORK/battery.json"
RACE_JSON="$WORK/race.json"
SSD_JSON="$WORK/ssd.json"
MEMBW_JSON="$WORK/membw.json"
VARIANCE_JSON="$WORK/variance.json"
NOACCEL_JSON="$WORK/noaccel.json"
THERMAL_JSON="$WORK/thermal.json"
GPU_JSON="$WORK/gpu.json"
LLAMA_JSON="$WORK/llama.json"

ignite "Phase 0: preflight"
{
  echo "=== uptime ==="
  uptime
  echo "=== top -l 1 -n 5 -o cpu ==="
  top -l 1 -n 5 -o cpu | tail -10 || true
  echo "=== pmset -g ps ==="
  pmset -g ps || true
  echo "=== networksetup -getairportpower ==="
  networksetup -getairportpower en0 2>/dev/null || echo "(no en0)"
} > "$PREFLIGHT_TXT" 2>&1

ignite "Phase 1: inventory"
"$SCRIPT_DIR/inventory.sh" > "$INVENTORY_JSON"

ignite "Phase 2: battery"
"$SCRIPT_DIR/battery.sh" > "$BATTERY_JSON"

# Strict mode (production / calibration use): the preconditions that are only
# WARNINGS by default become hard gates here. A run not on AC, or on a busy
# system, is not comparable to a golden baseline, so refuse to score it rather
# than burn 45 minutes on a number we would have to throw away. Same thresholds
# as the Phase 0 verdict below; this just promotes them and runs before the load
# phases. Inventory (perf-core count) and preflight have both run by now.
if [[ "$STRICT" -eq 1 ]]; then
  ignite "Strict mode: checking preconditions (AC power, quiet system)"
  if ! python3 - "$PREFLIGHT_TXT" "$INVENTORY_JSON" <<'PYEOF'
import json
import re
import sys

preflight = open(sys.argv[1]).read()
with open(sys.argv[2]) as f:
    inv = json.load(f).get("summary", {})

fails = []
if not ("AC" in preflight or "AC Power" in preflight):
    fails.append("not on AC power; a scored run must be on AC, not battery")
m = re.search(r"load averages?:\s+([\d.]+)", preflight)
n_perf = inv.get("perf_cores") or 0
if m and n_perf and float(m.group(1)) > n_perf * 0.5:
    fails.append(f"1m load avg {float(m.group(1)):.2f} above half the {n_perf} "
                 "perf cores; close background apps and rerun")

if fails:
    sys.stderr.write("\n  strict preconditions not met:\n")
    for reason in fails:
        sys.stderr.write(f"    - {reason}\n")
    sys.stderr.write("  Fix these and rerun, or drop --strict to run anyway "
                     "(advisory, not scored).\n\n")
    sys.exit(1)
PYEOF
  then
    echo "shakedown: aborting before the load phases (strict preconditions failed)" >&2
    exit 3
  fi
fi

# Run race + SSD benchmarks while the chassis is still cold. Cold race captures
# peak boost throughput unobscured by thermal saturation. SSD numbers are
# similarly cleaner before NVMe controllers warm up under chassis heat soak.
ignite "Phase 10: race benchmark (xz compression, ~30-60s)"
"$SCRIPT_DIR/race-bench.sh" > "$RACE_JSON"

ignite "Phase 11: SSD sequential read/write (~30s)"
if [[ "$NO_SUDO" -eq 1 ]]; then
  ALLOW_NO_PURGE=1 "$SCRIPT_DIR/ssd-test.sh" > "$SSD_JSON"
else
  "$SCRIPT_DIR/ssd-test.sh" > "$SSD_JSON"
fi

ignite "Phase 12: memory bandwidth (~15s)"
"$SCRIPT_DIR/memory-bandwidth.sh" > "$MEMBW_JSON"

ignite "Phase 4: CPU variance (~6-10 min depending on chassis)"
start_heartbeat
"$SCRIPT_DIR/cpu-variance.sh" > "$VARIANCE_JSON"
stop_heartbeat

if [[ "$RUN_NOACCEL" -eq 1 ]]; then
  ignite "Phase 4b: non-accelerated CPU variance (BLAKE2b, ~6 min)"
  start_heartbeat
  # Chassis is already hot from Phase 4, so a short re-warm is enough and we skip
  # the cold burst. Same script, non-accelerated workload.
  BURST_SEC=0 WARMUP_SEC="${NOACCEL_WARMUP_SEC:-60}" WORKLOAD=blake2b "$SCRIPT_DIR/cpu-variance.sh" > "$NOACCEL_JSON"
  stop_heartbeat
else
  ignite "Phase 4b: skipped (opt-in; pass --noaccel)"
  cat > "$NOACCEL_JSON" <<EOF
{"verdict":"skipped","verdict_reasons":["opt-in phase; pass --noaccel for a non-accelerated BLAKE2b variance pass"],"workload":"blake2b-parallel (non-accelerated)","data_quality":"skipped"}
EOF
fi

if [[ "$NO_SUDO" -eq 1 ]]; then
  ignite "Phase 5: skipped (--no-sudo)"
  cat > "$THERMAL_JSON" <<EOF
{"verdict":"skipped","verdict_reasons":["--no-sudo: thermal phase needs powermetrics + sudo"],"chassis_class":"$CHASSIS_CLASS","duration_s":0,"data_quality":"skipped"}
EOF
else
  ignite "Phase 5: sustained thermal load (~10 min, needs sudo)"
  start_heartbeat
  # shellcheck disable=SC2024  # the redirect target is a user-owned tempdir, not privileged.
  sudo CHASSIS_CLASS="$CHASSIS_CLASS" "$SCRIPT_DIR/thermal-load.sh" > "$THERMAL_JSON"
  stop_heartbeat
fi

if [[ "$RUN_GPU" -eq 1 ]]; then
  ignite "Phase 13: GPU variance (Metal compute, opt-in)"
  start_heartbeat
  "$SCRIPT_DIR/gpu-variance.sh" > "$GPU_JSON"
  stop_heartbeat
else
  ignite "Phase 13: skipped (opt-in; pass --gpu)"
  cat > "$GPU_JSON" <<EOF
{"verdict":"skipped","verdict_reasons":["opt-in phase; pass --gpu to compile and run a Metal GPU compute variance pass"],"workload":"metal-compute","data_quality":"skipped"}
EOF
fi

if [[ "$RUN_LLAMA" -eq 1 ]]; then
  ignite "Phase 14: llama.cpp combined load (opt-in, clones + builds)"
  start_heartbeat
  "$SCRIPT_DIR/llama-bench.sh" > "$LLAMA_JSON"
  stop_heartbeat
else
  ignite "Phase 14: skipped (opt-in; pass --llama)"
  cat > "$LLAMA_JSON" <<EOF
{"verdict":"skipped","verdict_reasons":["opt-in phase; pass --llama to clone, build, and run llama.cpp llama-bench (network + third-party code, see SECURITY.md)"],"workload":"llama.cpp llama-bench","data_quality":"skipped"}
EOF
fi

echo "shakedown: aggregating into canonical report"

mkdir -p "$REPO_ROOT/Reports/local" "$REPO_ROOT/Reports/submissions"

python3 - \
  "$TARGET_FILE" \
  "$PREFLIGHT_TXT" \
  "$INVENTORY_JSON" \
  "$BATTERY_JSON" \
  "$RACE_JSON" \
  "$SSD_JSON" \
  "$MEMBW_JSON" \
  "$VARIANCE_JSON" \
  "$NOACCEL_JSON" \
  "$THERMAL_JSON" \
  "$GPU_JSON" \
  "$LLAMA_JSON" \
  "$REPO_ROOT/Reports/local" \
  "$REPO_ROOT/Reports/submissions" \
  "$TARGET" \
  "$NOTES" \
<<'PYEOF'
import copy
import datetime
import json
import os
import re
import sys

(target_file, preflight_txt, inv_path, bat_path, race_path, ssd_path,
 membw_path, var_path, noaccel_path, thr_path, gpu_path, llama_path,
 local_dir, submissions_dir, target_name, notes) = sys.argv[1:17]

SHAKEDOWN_VERSION = "0.1.0"
SCHEMA_VERSION = "1.4"

def load(path):
    with open(path) as f:
        return json.load(f)

target = load(target_file) if target_file else None
inventory = load(inv_path)
battery = load(bat_path)
race = load(race_path)
ssd = load(ssd_path)
membw = load(membw_path)
variance = load(var_path)
noaccel = load(noaccel_path)
thermal = load(thr_path)
gpu = load(gpu_path)
llama = load(llama_path)

inv_summary = inventory.get("summary", {})

with open(preflight_txt) as f:
    preflight_raw = f.read()

load_avg_1m = None
m = re.search(r"load averages?:\s+([\d.]+)", preflight_raw)
if m:
    load_avg_1m = float(m.group(1))
top_lines = []
for line in preflight_raw.splitlines():
    if re.match(r"^\s*\d+\s+\S+\s+\d+\.\d+", line):
        parts = line.split()
        if len(parts) >= 3:
            top_lines.append(f"{parts[1]} {parts[2]}%")
top_lines = top_lines[:5]
ac_power = "AC" in preflight_raw or "AC Power" in preflight_raw
wifi_on = "Wi-Fi Power (en0): On" in preflight_raw

preflight_verdict = "pass"
preflight_reasons = []
n_perf = inv_summary.get("perf_cores") or 0
if load_avg_1m is not None and n_perf and load_avg_1m > n_perf * 0.5:
    preflight_verdict = "warn"
    preflight_reasons.append(
        f"1m load avg {load_avg_1m:.2f} above half perf-core count ({n_perf}), "
        f"close background apps before trusting variance numbers"
    )
if not ac_power:
    preflight_verdict = "warn"
    preflight_reasons.append("not on AC power, sustained-perf tests assume AC")

# In strict mode the gate already aborted before the load phases if a precondition
# failed, so reaching this point means they were met. Record that the run was gated.
strict_mode = os.environ.get("STRICT") == "1"
if strict_mode:
    preflight_reasons.append("strict mode: preconditions gated before the load phases")

chip = inv_summary.get("chip") or ""
mem_gb = inv_summary.get("memory_gb")
# Search across model + model_identifier, the size suffix shows up in either
# field depending on generation (Intel "MacBookPro16,1" vs Apple Silicon "Mac17,1").
model_haystack = " ".join(filter(None, [inv_summary.get("model"), inv_summary.get("model_identifier")]))
detected_screen = inv_summary.get("screen_inches")

ssd_smart = None
for s in inventory.get("storage", []) or []:
    if s.get("smart"):
        ssd_smart = s["smart"]
        break

inv_verdict = "pass"
inv_reasons = []
inv_asserts = {}

if target:
    inv_asserts = {
        "chip_pattern_matched": bool(target.get("chip_pattern") and target["chip_pattern"] in chip),
        "memory_gb_matched": (target.get("memory_gb") is None) or (target.get("memory_gb") == mem_gb),
        "model_must_include_matched": bool(target.get("model_must_include") and target["model_must_include"] in model_haystack),
        "screen_inches_matched": (target.get("screen_inches") is None) or (detected_screen is None) or (target.get("screen_inches") == detected_screen),
    }
    if ssd_smart:
        inv_asserts["ssd_smart"] = ssd_smart
    if not inv_asserts["chip_pattern_matched"]:
        inv_verdict = "fail"
        inv_reasons.append(f"chip '{chip}' does not contain target pattern '{target.get('chip_pattern')}'")
    if not inv_asserts["memory_gb_matched"]:
        inv_verdict = "fail"
        inv_reasons.append(f"memory {mem_gb} GB does not match target {target.get('memory_gb')} GB")
    if not inv_asserts["model_must_include_matched"]:
        if inv_verdict == "pass":
            inv_verdict = "warn"
        inv_reasons.append(
            f"model '{model_haystack}' does not include target substring '{target.get('model_must_include')}'"
        )
    if not inv_asserts["screen_inches_matched"]:
        if inv_verdict == "pass":
            inv_verdict = "warn"
        inv_reasons.append(
            f"built-in display reads as {detected_screen}-inch but target expects "
            f"{target.get('screen_inches')}-inch"
        )
else:
    inv_asserts = {"ran_without_target": True, "ssd_smart": ssd_smart}
    inv_reasons.append("no target preset specified, recorded actual values without asserting")

if ssd_smart and ssd_smart != "Verified":
    inv_verdict = "fail"
    inv_reasons.append(f"SSD SMART status '{ssd_smart}' (expected 'Verified')")

cycle = battery.get("cycle_count")
max_pct = battery.get("max_capacity_pct")
condition = battery.get("condition")

bat_verdict = "pass"
bat_reasons = []
# Cycle count + "below 99%" warn assume a new-from-factory unit; only apply
# them when --target is given (signals "I'm verifying a new purchase").
# Real-degradation checks (<95% capacity, abnormal condition) apply either way.
if target:
    if isinstance(cycle, int) and cycle > 5:
        bat_verdict = "fail"
        bat_reasons.append(f"cycle_count {cycle} > 5, likely a returned/refurb unit, not new-from-factory")
    elif isinstance(cycle, int) and cycle > 1:
        bat_verdict = "warn"
        bat_reasons.append(f"cycle_count {cycle} above the typical factory range (0–1)")
    if isinstance(max_pct, (int, float)) and max_pct < 99 and (not isinstance(max_pct, (int, float)) or max_pct >= 95):
        bat_verdict = "warn"
        bat_reasons.append(f"max_capacity_pct {max_pct}% below the 99% expected on a new unit")
elif isinstance(cycle, int):
    bat_reasons.append(f"cycle_count {cycle} (informational, no target, factory-fresh check skipped)")
if isinstance(max_pct, (int, float)) and max_pct < 95:
    bat_verdict = "fail"
    bat_reasons.append(f"max_capacity_pct {max_pct}% < 95%")
if condition and condition != "Normal":
    bat_verdict = "fail"
    bat_reasons.append(f"battery condition '{condition}' (expected 'Normal')")
if not bat_reasons:
    bat_reasons.append("battery healthy")

battery_details = {k: v for k, v in battery.items() if not k.startswith("_") and k != "battery_serial"}

sensors_required = ["Camera", "Microphone", "Wi-Fi", "Bluetooth"]
present = []
missing = []
cameras = inventory.get("cameras") or []
if cameras:
    present.append(f"Camera ({cameras[0]})")
else:
    missing.append("Camera")
audio = inventory.get("audio") or []
mic = any("microphone" in (a.get("name", "") or "").lower() for a in audio) or any(
    a.get("input") for a in audio
)
spk = any(a.get("output") for a in audio)
if mic:
    present.append("Microphone")
else:
    missing.append("Microphone")
if spk:
    present.append("Speakers")
else:
    missing.append("Speakers")
if inventory.get("wifi_present"):
    present.append("Wi-Fi")
else:
    missing.append("Wi-Fi")
if inventory.get("bluetooth_present"):
    present.append("Bluetooth")
else:
    missing.append("Bluetooth")

sensors_verdict = "fail" if missing else "pass"
sensors_reasons = ([f"missing: {', '.join(missing)}"] if missing else ["all expected sensors present"])

variance_verdict = variance.get("verdict", "fail")
variance_reasons = variance.get("verdict_reasons") or []
variance_details = {k: v for k, v in variance.items() if k not in ("verdict", "verdict_reasons")}

thermal_verdict = thermal.get("verdict", "fail")
thermal_reasons = thermal.get("verdict_reasons") or []
thermal_details = {k: v for k, v in thermal.items() if k not in ("verdict", "verdict_reasons", "raw_log_path")}

# Race + SSD benchmarks default to "info" verdict in v0.2 (no pass/fail
# thresholds yet, they're calibration inputs). "info" is treated as not-failing
# and not-warning in the overall result computation below.
race_verdict = race.get("verdict", "info")
race_reasons = race.get("verdict_reasons") or []
race_details = {k: v for k, v in race.items() if k not in ("verdict", "verdict_reasons")}

ssd_verdict = ssd.get("verdict", "info")
ssd_reasons = ssd.get("verdict_reasons") or []
ssd_details = {k: v for k, v in ssd.items() if k not in ("verdict", "verdict_reasons")}

membw_verdict = membw.get("verdict", "info")
membw_reasons = membw.get("verdict_reasons") or []
membw_details = {k: v for k, v in membw.items() if k not in ("verdict", "verdict_reasons")}

# Phase 4b (non-accelerated variance) is a real pass/warn/fail variance pass when
# it runs; without --noaccel it is a skipped stub. Default to a non-failing
# verdict if the field is somehow absent, since the phase is opt-in.
noaccel_verdict = noaccel.get("verdict", "info")
noaccel_reasons = noaccel.get("verdict_reasons") or []
noaccel_details = {k: v for k, v in noaccel.items() if k not in ("verdict", "verdict_reasons")}

gpu_verdict = gpu.get("verdict", "info")
gpu_reasons = gpu.get("verdict_reasons") or []
gpu_details = {k: v for k, v in gpu.items() if k not in ("verdict", "verdict_reasons")}

llama_verdict = llama.get("verdict", "info")
llama_reasons = llama.get("verdict_reasons") or []
llama_details = {k: v for k, v in llama.items() if k not in ("verdict", "verdict_reasons")}

skipped_phases = {
    "6_display": "run ./Verification/scripts/display-test.sh and fill in manual_responses",
    "7_physical": "follow Runbook Phase 7 manual checklist",
    "8_apple_diagnostics": "reboot into Diagnostics (Cmd-D from startup options); record code",
    "9_idle_drain": "optional, see Runbook Phase 9",
}

def phase_block(verdict, duration_s, details, reasons):
    return {
        "verdict": verdict,
        "duration_s": duration_s,
        "details": details,
        "verdict_reasons": reasons,
    }

storage_gb = None
for s in inventory.get("storage", []) or []:
    cap = s.get("capacity") or ""
    m = re.search(r"([\d,.]+)\s*(TB|GB)", cap)
    if m:
        val = float(m.group(1).replace(",", ""))
        if m.group(2) == "TB":
            val *= 1024
        storage_gb = int(round(val))
        break

unit_block = {
    "model": inv_summary.get("model"),
    "model_identifier": inv_summary.get("model_identifier"),
    "chip": inv_summary.get("chip"),
    "is_apple_silicon": inv_summary.get("is_apple_silicon"),
    "perf_cores": inv_summary.get("perf_cores"),
    "efficiency_cores": inv_summary.get("efficiency_cores"),
    "logical_cpus": inv_summary.get("logical_cpus"),
    "memory_gb": inv_summary.get("memory_gb"),
    "screen_inches": inv_summary.get("screen_inches"),
    "storage_gb": storage_gb,
    "macos_version": inv_summary.get("macos_version"),
    "kernel_version": inv_summary.get("kernel_version"),
    "serial_hash": inv_summary.get("serial_hash"),
    "power_adapter": inventory.get("power_adapter"),
}
if inv_summary.get("serial_number"):
    unit_block["serial_number"] = inv_summary["serial_number"]

phases = {
    "0_preflight": phase_block(preflight_verdict, 60, {
        "load_avg_1m": load_avg_1m,
        "top_cpu_consumers": top_lines,
        "ac_power_connected": ac_power,
        "wifi_connected": wifi_on,
        "strict_mode": strict_mode,
    }, preflight_reasons or ["system quiet"]),
    "1_inventory": phase_block(inv_verdict, 1, {"asserts": inv_asserts}, inv_reasons or ["target asserts matched"]),
    "2_battery": phase_block(bat_verdict, 1, battery_details, bat_reasons),
    "3_sensors": phase_block(sensors_verdict, 1, {"expected_present": present, "missing": missing}, sensors_reasons),
    "10_race_bench": phase_block(race_verdict, int(race_details.get("wall_seconds") or 0), race_details, race_reasons),
    "11_ssd_test": phase_block(ssd_verdict, int((ssd_details.get("write_seconds") or 0) + (ssd_details.get("read_seconds") or 0)), ssd_details, ssd_reasons),
    "12_memory_bandwidth": phase_block(membw_verdict, int(membw_details.get("wall_seconds") or 0), membw_details, membw_reasons),
    "4_cpu_variance": phase_block(variance_verdict, variance_details.get("warmup_sec", 0) + variance_details.get("iterations", 0) * variance_details.get("seconds_per_iter", 0) + variance_details.get("burst_sec", 0), variance_details, variance_reasons),
    "4b_cpu_variance_noaccel": phase_block(noaccel_verdict, noaccel_details.get("warmup_sec", 0) + noaccel_details.get("iterations", 0) * noaccel_details.get("seconds_per_iter", 0) + noaccel_details.get("burst_sec", 0), noaccel_details, noaccel_reasons),
    "5_thermal_load": phase_block(thermal_verdict, thermal_details.get("duration_s", 600), thermal_details, thermal_reasons),
    "13_gpu_variance": phase_block(gpu_verdict, int(gpu_details.get("wall_seconds") or 0), gpu_details, gpu_reasons),
    "14_llama_bench": phase_block(llama_verdict, int(llama_details.get("wall_seconds") or 0), llama_details, llama_reasons),
}
for name, hint in skipped_phases.items():
    phases[name] = phase_block("skipped", 0, {"note": hint}, ["not run by orchestrator"])

phase_verdicts = [p["verdict"] for p in phases.values()]
if "fail" in phase_verdicts:
    result = "FAIL"
    failing = [name for name, p in phases.items() if p["verdict"] == "fail"]
    result_reason = f"failed phases: {', '.join(failing)}"
elif "warn" in phase_verdicts:
    result = "PASS"
    warning = [name for name, p in phases.items() if p["verdict"] == "warn"]
    result_reason = f"all phases passed, warns on: {', '.join(warning)}"
else:
    result = "PASS"
    result_reason = "all phases passed; no defect signatures detected"

# Calibrated baseline check (production-QA style). When baselines/<preset>.json
# exists for this target, bin each metric against its golden control limit; a
# metric outside its limit escalates the overall result to FAIL. Absent a
# baseline the verdict stays within-unit-only (advisory). See Production QA.md.
baseline_check = None
if target_name:
    repo_root = os.path.dirname(os.path.dirname(local_dir))
    baseline_path = os.path.join(repo_root, "baselines", target_name + ".json")
    if os.path.exists(baseline_path):
        with open(baseline_path) as bf:
            baseline = json.load(bf)
        checks = []
        for key, spec in (baseline.get("metrics") or {}).items():
            pk, _, mpath = key.partition(".")
            node = phases.get(pk, {}).get("details", {})
            for part in mpath.split("."):
                node = node.get(part) if isinstance(node, dict) else None
            if not isinstance(node, (int, float)):
                continue
            higher = spec.get("higher_better", True)
            entry = {"metric": key, "value": node, "golden": spec.get("golden"), "pass": True}
            if higher and spec.get("min") is not None:
                entry["min"] = spec["min"]
                entry["pass"] = node >= spec["min"]
            elif (not higher) and spec.get("max") is not None:
                entry["max"] = spec["max"]
                entry["pass"] = node <= spec["max"]
            checks.append(entry)
        failed = [c for c in checks if not c["pass"]]
        baseline_check = {
            "baseline_preset": baseline.get("preset"),
            "n_samples": baseline.get("n_samples"),
            "checks": checks,
            "verdict": "fail" if failed else "pass",
        }
        if failed:
            reason = "below golden baseline: " + ", ".join(
                f"{c['metric']} {c['value']} vs golden {c.get('golden')}" for c in failed)
            result_reason = (result_reason + "; " + reason) if result == "FAIL" else reason
            result = "FAIL"

if target:
    target_block = {"preset": target_name}
    target_block.update({k: v for k, v in target.items() if not k.startswith("_")})
else:
    target_block = {
        "preset": None,
        "thermal_chassis_class": variance.get("chassis_class"),
        "note": "ran without --target, inventory asserts skipped",
    }

report_full = {
    "schema_version": SCHEMA_VERSION,
    "shakedown_version": SHAKEDOWN_VERSION,
    "timestamp": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "target": target_block,
    "unit": unit_block,
    "phases": phases,
    "result": result,
    "result_reason": result_reason,
    "baseline_check": baseline_check,
    "submission_safe": True,
    "store_location": None,
    "purchase_date": None,
}
if notes:
    report_full["notes"] = notes
    report_full["submission_safe"] = False

report_full["phases"]["1_inventory"]["details"]["_raw_inventory"] = inventory
report_full["phases"]["2_battery"]["details"]["_raw_battery"] = battery

date_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
serial_hash = inv_summary.get("serial_hash") or ""
m = re.search(r"sha256:([0-9a-f]{4,})", serial_hash)
hash4 = m.group(1)[:4] if m else "xxxx"
if target_name:
    slug = target_name
else:
    chassis_slug = variance.get("chassis_class") or "unknown"
    mem_slug = f"{mem_gb}gb" if mem_gb else "unknown"
    slug = f"{chassis_slug}-{mem_slug}"
filename = f"{date_str}-{slug}-{hash4}.json"
local_path = os.path.join(local_dir, filename)
submission_path = os.path.join(submissions_dir, filename)

with open(local_path, "w") as f:
    json.dump(report_full, f, indent=2, default=str)

report_sub = copy.deepcopy(report_full)
report_sub["unit"].pop("serial_number", None)
for phase_name, phase in report_sub["phases"].items():
    details = phase.get("details", {})
    for k in list(details.keys()):
        if k.startswith("_raw_"):
            details.pop(k)
    if "raw_log_path" in details:
        details.pop("raw_log_path")
report_sub["submission_safe"] = not bool(notes)
if notes:
    report_sub["notes"] = notes

with open(submission_path, "w") as f:
    json.dump(report_sub, f, indent=2, default=str)

print(json.dumps({
    "result": result,
    "result_reason": result_reason,
    "local_path": local_path,
    "submission_path": submission_path,
    "submission_safe": report_sub["submission_safe"],
}, indent=2))

# Human-readable verdict banner to stderr, printed last so it is the final
# thing on screen: the "by the end I know" payoff.
_tty = sys.stderr.isatty()
_c = ("\033[1;32m" if result == "PASS" else "\033[1;31m") if _tty else ""
_d = "\033[2m" if _tty else ""
_x = "\033[0m" if _tty else ""
_bar = "=" * 66
print(f"\n{_c}{_bar}", file=sys.stderr)
print(f"  SHAKEDOWN VERDICT: {result}", file=sys.stderr)
print(f"{_bar}{_x}", file=sys.stderr)
print(f"  {result_reason}", file=sys.stderr)
if baseline_check is not None:
    _ck = baseline_check.get("checks") or []
    _within = sum(1 for c in _ck if c.get("pass"))
    print(f"{_d}  Binned against the golden baseline for {baseline_check.get('baseline_preset')} "
          f"({baseline_check.get('n_samples')} known-good samples):{_x}", file=sys.stderr)
    print(f"{_d}  {_within}/{len(_ck)} metrics within their golden limits. This is a calibrated"
          f" verdict.{_x}", file=sys.stderr)
else:
    if result == "PASS":
        print(f"{_d}  No batch performance-defect signature: CPU variance, thermal, memory,{_x}",
              file=sys.stderr)
        print(f"{_d}  and GPU all within range (the defect class Apple QA has been missing).{_x}",
              file=sys.stderr)
    print(f"{_d}  No golden baseline for this SKU yet, so this verdict is within-unit only",
          file=sys.stderr)
    print(f"  (advisory). For a calibrated verdict, build one from known-good units with",
          file=sys.stderr)
    print(f"  make-baseline.sh, or compare against one with compare-reports.sh.{_x}", file=sys.stderr)
print(f"{_d}  Report saved: {submission_path}{_x}", file=sys.stderr)
print(f"{_c}{_bar}{_x}\n", file=sys.stderr)
PYEOF
