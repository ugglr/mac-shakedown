#!/bin/bash
# inventory.sh — dump hardware inventory as JSON for the report's `unit` block.
# Output: JSON to stdout. The `summary` block is the comparable / submission-safe
# subset; serials are SHA-256 hashed by default (set INCLUDE_PLAINTEXT_SERIAL=1 to
# also include the raw serial, e.g. for warranty cross-reference). The `_raw_…`
# blocks contain the full system_profiler dump for local debugging — strip these
# before submission to the aggregator (they may include Bluetooth-paired device
# IDs, Wi-Fi SSIDs, USB device serials, etc.).

set -euo pipefail

INCLUDE_PLAINTEXT_SERIAL=${INCLUDE_PLAINTEXT_SERIAL:-0}

python3 - "$INCLUDE_PLAINTEXT_SERIAL" <<'PYEOF'
import hashlib
import json
import subprocess
import sys

INCLUDE_PLAINTEXT_SERIAL = sys.argv[1] == "1"

DATATYPES = [
    "SPHardwareDataType",
    "SPSoftwareDataType",
    "SPMemoryDataType",
    "SPNVMeDataType",
    "SPDisplaysDataType",
    "SPAudioDataType",
    "SPCameraDataType",
    "SPThunderboltDataType",
    "SPUSBDataType",
    "SPBluetoothDataType",
    "SPAirPortDataType",
    "SPPowerDataType",
]

def run_sp(dt):
    try:
        out = subprocess.check_output(
            ["system_profiler", "-json", dt],
            stderr=subprocess.DEVNULL,
        )
        return json.loads(out)
    except Exception as e:
        return {"_error": str(e)}

def sysctl(key):
    try:
        return subprocess.check_output(
            ["sysctl", "-n", key], stderr=subprocess.DEVNULL
        ).decode().strip() or None
    except Exception:
        return None

def hash_serial(s):
    if not s:
        return None
    return "sha256:" + hashlib.sha256(s.encode("utf-8")).hexdigest()

raw = {dt: run_sp(dt) for dt in DATATYPES}

def first(d, k):
    v = d.get(k, [])
    return v[0] if isinstance(v, list) and v else (v if isinstance(v, dict) else {})

hw = first(raw.get("SPHardwareDataType", {}), "SPHardwareDataType")
sw = first(raw.get("SPSoftwareDataType", {}), "SPSoftwareDataType")

# Memory size — guard against non-numeric sysctl output.
memsize_raw = sysctl("hw.memsize")
try:
    memsize_bytes = int(memsize_raw or 0)
    memsize_gb = round(memsize_bytes / (1024**3))
except (ValueError, TypeError):
    memsize_bytes = None
    memsize_gb = None

raw_serial = hw.get("serial_number")

summary = {
    # Identity (comparable across submissions)
    "model": hw.get("machine_model"),
    "model_identifier": hw.get("machine_name"),
    # Apple Silicon reports `chip_type`; Intel reports `cpu_type` instead.
    "chip": hw.get("chip_type") or hw.get("cpu_type"),
    "is_apple_silicon": bool(hw.get("chip_type")),
    "physical_memory": hw.get("physical_memory"),
    "memory_gb": memsize_gb,
    "perf_cores": int(sysctl("hw.perflevel0.physicalcpu") or 0) or None,
    "efficiency_cores": int(sysctl("hw.perflevel1.physicalcpu") or 0) or None,
    "logical_cpus": int(sysctl("hw.ncpu") or 0) or None,
    "cpu_brand": sysctl("machdep.cpu.brand_string"),
    "macos_version": sw.get("os_version"),
    "kernel_version": sw.get("kernel_version"),
    "boot_volume": sw.get("boot_volume"),
    # Hashed serial — README claims this; this is where it actually happens.
    "serial_hash": hash_serial(raw_serial),
}
if INCLUDE_PLAINTEXT_SERIAL:
    summary["serial_number"] = raw_serial
    summary["_warn"] = "plaintext serial included by INCLUDE_PLAINTEXT_SERIAL=1; strip before submission"

# Storage (model + revision useful for comparison — Apple has shipped 256GB
# single-die SSD perf regressions in the past).
storage = []
nvme_root = raw.get("SPNVMeDataType", {}).get("SPNVMeDataType", [])
for controller in nvme_root:
    for item in controller.get("_items", []) or []:
        storage.append({
            "name": item.get("_name"),
            "capacity": item.get("size"),
            "smart": item.get("smart_status"),
            "model": item.get("device_model"),
            "revision": item.get("device_revision"),
        })

# Displays
displays = []
for gpu in raw.get("SPDisplaysDataType", {}).get("SPDisplaysDataType", []) or []:
    for d in gpu.get("spdisplays_ndrvs", []) or []:
        displays.append({
            "name": d.get("_name"),
            "resolution": d.get("_spdisplays_resolution"),
            "pixel_resolution": d.get("_spdisplays_pixels"),
            "refresh_rate": d.get("_spdisplays_refresh-rate"),
            "type": "built-in" if d.get("spdisplays_connection_type") == "spdisplays_internal" else "external",
        })

# Thunderbolt ports
tb = raw.get("SPThunderboltDataType", {}).get("SPThunderboltDataType", []) or []
thunderbolt_ports = len(tb)

# Cameras
cam = raw.get("SPCameraDataType", {}).get("SPCameraDataType", []) or []
cameras = [c.get("_name") for c in cam]

# Audio
audio_items = []
for sect in raw.get("SPAudioDataType", {}).get("SPAudioDataType", []) or []:
    for it in sect.get("_items", []) or []:
        audio_items.append({
            "name": it.get("_name"),
            "manufacturer": it.get("coreaudio_device_manufacturer"),
            "input": it.get("coreaudio_device_input"),
            "output": it.get("coreaudio_device_output"),
        })

# Bluetooth & Wi-Fi presence (presence only; details are in _raw_*)
bt_present = bool(raw.get("SPBluetoothDataType", {}).get("SPBluetoothDataType"))
wifi_present = bool(raw.get("SPAirPortDataType", {}).get("SPAirPortDataType"))

# Power adapter info (affects sustained-perf headroom on laptops while charging).
adapter = None
for section in raw.get("SPPowerDataType", {}).get("SPPowerDataType", []) or []:
    name = (section.get("_name", "") or "").lower()
    if "ac charger" in name or "power adapter" in name or "ac power" in name:
        adapter = {
            "name":      section.get("_name"),
            "wattage":   section.get("sppower_ac_charger_watts") or section.get("Watts"),
            "connected": section.get("sppower_ac_charger_connected") == "spbattery_charger_connected_yes" if section.get("sppower_ac_charger_connected") else None,
            "charging":  section.get("sppower_ac_charger_charging") == "spbattery_charger_charging_yes"  if section.get("sppower_ac_charger_charging")  else None,
        }
        break

result = {
    "summary": summary,
    "storage": storage,
    "displays": displays,
    "thunderbolt_ports": thunderbolt_ports,
    "cameras": cameras,
    "audio": audio_items,
    "bluetooth_present": bt_present,
    "wifi_present": wifi_present,
    "power_adapter": adapter,
    # Full system_profiler dump — kept for local debugging. Strip before
    # submitting to the aggregator: contains paired BT device IDs, Wi-Fi SSIDs,
    # USB device serials, etc. — fingerprints the user environment.
    "_raw_system_profiler": raw,
}

print(json.dumps(result, indent=2, default=str))
PYEOF
