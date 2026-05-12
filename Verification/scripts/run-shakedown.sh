#!/bin/bash
# run-shakedown.sh — orchestrator: runs the auto-runnable phases end-to-end and
# writes two JSON reports: a full local copy and a sanitized submission copy.
#
# Usage:
#   ./Verification/scripts/run-shakedown.sh --target mbp-16-m5-max-64
#
# Writes:
#   Reports/local/<filename>.json       — full output, gitignored (keeps _raw_* fields)
#   Reports/submissions/<filename>.json — sanitized, committable as a PR
#
# Phases 6 (display), 7 (physical), 8 (Apple Diagnostics), 9 (idle drain) emit
# `verdict: "skipped"` placeholders — friend hand-edits the local copy if they
# ran any of those, then re-runs the sanitize step or copies the result.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET=""
NOTES=""
NO_SUDO=0

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
    -h|--help)
      cat <<HELP
Usage: $(basename "$0") [--target <preset>] [--no-sudo] [--notes "free-form notes"]

  --target <preset>   optional. Target preset name (file under targets/ without .json)
                      e.g. mbp-16-m5-max-64, macbook-air-m5-16, mbp-16-intel-2019.
                      Without a target, inventory asserts are skipped — useful for
                      Macs that don't yet have a preset.
  --no-sudo           skip Phase 5 (sustained thermal load) — that's the only phase
                      that needs sudo. Phase 4 (variance) still runs and is the
                      headline test. Alias: --skip-thermal.
  --notes "..."       optional free-form note to embed in the report. Setting any
                      note flips submission_safe to false (notes may contain PII).

Chassis class: read from the preset when --target is given; otherwise
auto-detected from system_profiler (override with CHASSIS_CLASS env var).
HELP
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

TARGET_FILE=""
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
  # No target and no override — auto-detect chassis from machine_name.
  # Mac Pro (Intel desktop) and MacBook Pro both contain "Pro"; check for
  # the MacBook prefix first so Mac Pro doesn't get misclassified as a laptop.
  CHASSIS_CLASS=$(python3 <<'PYEOF'
import json
import subprocess
import sys
try:
    sp = json.loads(subprocess.check_output(
        ["system_profiler", "-json", "SPHardwareDataType"],
        stderr=subprocess.DEVNULL,
    ))
    hw = sp["SPHardwareDataType"][0]
except Exception:
    sys.exit(1)
model = hw.get("machine_name") or ""
is_apple_silicon = bool(hw.get("chip_type"))
is_laptop = "MacBook" in model
if is_apple_silicon:
    print("fanless" if (is_laptop and "Air" in model) else
          "active-cooled-pro" if is_laptop else "desktop")
else:
    print("intel-laptop" if is_laptop else "intel-desktop")
PYEOF
) || {
    echo "run-shakedown.sh: could not auto-detect chassis class." >&2
    echo "  Set CHASSIS_CLASS env var explicitly:" >&2
    echo "  fanless | active-cooled-pro | desktop | intel-laptop | intel-desktop" >&2
    exit 2
  }
fi
export CHASSIS_CLASS

ignite() {
  # Build-up flame animation before a phase. ~700 ms total — short enough that
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
  if [[ "$NO_SUDO" -eq 1 ]]; then
    duration_hint="~8 min of sustained 100% CPU load (Phase 4 variance)"
  else
    duration_hint="~18 min of sustained 100% CPU load (Phase 4 variance + Phase 5 thermal)"
  fi
  cat <<INFO >&2

About to run $duration_hint. Fans will spin up loud and the chassis will get
hot. macOS throttles to protect the chip, so nothing dangerous — but expect a
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
  # on Intel takes ~8 min — without this, the user gets a second password
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
VARIANCE_JSON="$WORK/variance.json"
THERMAL_JSON="$WORK/thermal.json"

ignite "Phase 0 — preflight"
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

ignite "Phase 1 — inventory"
"$SCRIPT_DIR/inventory.sh" > "$INVENTORY_JSON"

ignite "Phase 2 — battery"
"$SCRIPT_DIR/battery.sh" > "$BATTERY_JSON"

ignite "Phase 4 — CPU variance (~6-10 min depending on chassis)"
start_heartbeat
"$SCRIPT_DIR/cpu-variance.sh" > "$VARIANCE_JSON"
stop_heartbeat

if [[ "$NO_SUDO" -eq 1 ]]; then
  ignite "Phase 5 — skipped (--no-sudo)"
  cat > "$THERMAL_JSON" <<EOF
{"verdict":"skipped","verdict_reasons":["--no-sudo: thermal phase needs powermetrics + sudo"],"chassis_class":"$CHASSIS_CLASS","duration_s":0,"data_quality":"skipped"}
EOF
else
  ignite "Phase 5 — sustained thermal load (~10 min, needs sudo)"
  start_heartbeat
  # shellcheck disable=SC2024  # the redirect target is a user-owned tempdir, not privileged.
  sudo CHASSIS_CLASS="$CHASSIS_CLASS" "$SCRIPT_DIR/thermal-load.sh" > "$THERMAL_JSON"
  stop_heartbeat
fi

echo "shakedown: aggregating into canonical report"

mkdir -p "$REPO_ROOT/Reports/local" "$REPO_ROOT/Reports/submissions"

python3 - \
  "$TARGET_FILE" \
  "$PREFLIGHT_TXT" \
  "$INVENTORY_JSON" \
  "$BATTERY_JSON" \
  "$VARIANCE_JSON" \
  "$THERMAL_JSON" \
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

(target_file, preflight_txt, inv_path, bat_path, var_path, thr_path,
 local_dir, submissions_dir, target_name, notes) = sys.argv[1:11]

SHAKEDOWN_VERSION = "0.1.0"
SCHEMA_VERSION = "1.0"

def load(path):
    with open(path) as f:
        return json.load(f)

target = load(target_file) if target_file else None
inventory = load(inv_path)
battery = load(bat_path)
variance = load(var_path)
thermal = load(thr_path)

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
        f"1m load avg {load_avg_1m:.2f} above half perf-core count ({n_perf}) — "
        f"close background apps before trusting variance numbers"
    )
if not ac_power:
    preflight_verdict = "warn"
    preflight_reasons.append("not on AC power — sustained-perf tests assume AC")

chip = inv_summary.get("chip") or ""
mem_gb = inv_summary.get("memory_gb")
# Search across model + model_identifier — the size suffix shows up in either
# field depending on generation (Intel "MacBookPro16,1" vs Apple Silicon "Mac17,1").
model_haystack = " ".join(filter(None, [inv_summary.get("model"), inv_summary.get("model_identifier")]))

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
            f"model '{model_haystack}' does not include target substring '{target.get('model_must_include')}' "
            f"— system_profiler does not reliably expose screen size on Apple Silicon; verify manually"
        )
else:
    inv_asserts = {"ran_without_target": True, "ssd_smart": ssd_smart}
    inv_reasons.append("no target preset specified — recorded actual values without asserting")

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
        bat_reasons.append(f"cycle_count {cycle} > 5 — likely a returned/refurb unit, not new-from-factory")
    elif isinstance(cycle, int) and cycle > 1:
        bat_verdict = "warn"
        bat_reasons.append(f"cycle_count {cycle} above the typical factory range (0–1)")
    if isinstance(max_pct, (int, float)) and max_pct < 99 and (not isinstance(max_pct, (int, float)) or max_pct >= 95):
        bat_verdict = "warn"
        bat_reasons.append(f"max_capacity_pct {max_pct}% below the 99% expected on a new unit")
elif isinstance(cycle, int):
    bat_reasons.append(f"cycle_count {cycle} (informational — no target, factory-fresh check skipped)")
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

skipped_phases = {
    "6_display": "run ./Verification/scripts/display-test.sh and fill in manual_responses",
    "7_physical": "follow Runbook Phase 7 manual checklist",
    "8_apple_diagnostics": "reboot into Diagnostics (Cmd-D from startup options); record code",
    "9_idle_drain": "optional — see Runbook Phase 9",
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
    }, preflight_reasons or ["system quiet"]),
    "1_inventory": phase_block(inv_verdict, 1, {"asserts": inv_asserts}, inv_reasons or ["target asserts matched"]),
    "2_battery": phase_block(bat_verdict, 1, battery_details, bat_reasons),
    "3_sensors": phase_block(sensors_verdict, 1, {"expected_present": present, "missing": missing}, sensors_reasons),
    "4_cpu_variance": phase_block(variance_verdict, variance_details.get("warmup_sec", 0) + variance_details.get("iterations", 0) * variance_details.get("seconds_per_iter", 0) + variance_details.get("burst_sec", 0), variance_details, variance_reasons),
    "5_thermal_load": phase_block(thermal_verdict, thermal_details.get("duration_s", 600), thermal_details, thermal_reasons),
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

if target:
    target_block = {"preset": target_name}
    target_block.update({k: v for k, v in target.items() if not k.startswith("_")})
else:
    target_block = {
        "preset": None,
        "thermal_chassis_class": variance.get("chassis_class"),
        "note": "ran without --target — inventory asserts skipped",
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
PYEOF

cat <<INFO >&2

shakedown: done.

Next steps:
  1. Review the submission JSON for any leftover PII:
     cat Reports/submissions/<filename>
  2. If you ran the manual phases (display / physical / Apple Diagnostics),
     hand-edit the local file then copy a sanitized version to submissions/.
  3. Open a PR adding the submission JSON to help calibrate v0.1 thresholds.
     See CONTRIBUTING.md for the submission flow.
INFO
