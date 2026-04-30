#!/bin/bash
# inventory.sh — dump hardware inventory as JSON
# Usage: ./inventory.sh
# Output: JSON to stdout with `summary` (key facts), `storage`, `displays`,
#         `cameras`, `audio`, `thunderbolt_ports`, plus full `raw` system_profiler.

set -euo pipefail

python3 - <<'PYEOF'
import json
import subprocess

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
        ).decode().strip()
    except Exception:
        return None

raw = {dt: run_sp(dt) for dt in DATATYPES}

def first(d, k):
    v = d.get(k, [])
    return v[0] if isinstance(v, list) and v else (v if isinstance(v, dict) else {})

hw = first(raw.get("SPHardwareDataType", {}), "SPHardwareDataType")
sw = first(raw.get("SPSoftwareDataType", {}), "SPSoftwareDataType")

memsize_bytes = int(sysctl("hw.memsize") or 0)
memsize_gb = round(memsize_bytes / (1024**3))

summary = {
    "model": hw.get("machine_model"),
    "model_identifier": hw.get("machine_name"),
    "chip": hw.get("chip_type"),
    "physical_memory": hw.get("physical_memory"),
    "memory_gb": memsize_gb,
    "serial_number": hw.get("serial_number"),
    "cpu_brand": sysctl("machdep.cpu.brand_string"),
    "perf_cores": sysctl("hw.perflevel0.physicalcpu"),
    "efficiency_cores": sysctl("hw.perflevel1.physicalcpu"),
    "logical_cpus": sysctl("hw.ncpu"),
    "macos_version": sw.get("os_version"),
    "kernel_version": sw.get("kernel_version"),
    "boot_volume": sw.get("boot_volume"),
}

# Storage
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

# Bluetooth & Wi-Fi presence
bt_present = bool(raw.get("SPBluetoothDataType", {}).get("SPBluetoothDataType"))
wifi_present = bool(raw.get("SPAirPortDataType", {}).get("SPAirPortDataType"))

result = {
    "summary": summary,
    "storage": storage,
    "displays": displays,
    "thunderbolt_ports": thunderbolt_ports,
    "cameras": cameras,
    "audio": audio_items,
    "bluetooth_present": bt_present,
    "wifi_present": wifi_present,
    "raw": raw,
}

print(json.dumps(result, indent=2, default=str))
PYEOF
