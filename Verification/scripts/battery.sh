#!/bin/bash
# battery.sh — battery health summary as JSON.
# Battery serial is SHA-256 hashed by default. Set INCLUDE_PLAINTEXT_SERIAL=1
# to also include the raw battery serial (typically for warranty cross-reference).
# `_raw_*` blocks are local-debug only; strip before submission.

set -euo pipefail

INCLUDE_PLAINTEXT_SERIAL=${INCLUDE_PLAINTEXT_SERIAL:-0}

python3 - "$INCLUDE_PLAINTEXT_SERIAL" <<'PYEOF'
import hashlib
import json
import re
import subprocess
import sys

INCLUDE_PLAINTEXT_SERIAL = sys.argv[1] == "1"

SIGNED_KEYS = {"Amperage", "InstantAmperage"}

def hash_serial(s):
    if not s:
        return None
    return "sha256:" + hashlib.sha256(str(s).encode("utf-8")).hexdigest()

def _coerce(k, v):
    v = v.strip()
    if v in ("Yes", "No"):
        return v == "Yes"
    try:
        n = int(v)
        # ioreg reports signed values as 64-bit unsigned. Negative amperage
        # (discharging) shows up as ~2^64. Convert back to signed.
        if k in SIGNED_KEYS and n > (1 << 63):
            n -= (1 << 64)
        return n
    except ValueError:
        return v

def ioreg_battery():
    try:
        out = subprocess.check_output(
            ["ioreg", "-rn", "AppleSmartBattery"],
            stderr=subprocess.DEVNULL,
        ).decode()
    except Exception:
        return {}
    keys = [
        "CycleCount", "DesignCapacity",
        "AppleRawMaxCapacity", "MaxCapacity",
        "NominalChargeCapacity", "AppleRawCurrentCapacity",
        "CurrentCapacity", "Temperature",
        "FullyCharged", "ExternalConnected",
        "IsCharging", "AvgTimeToFull", "AvgTimeToEmpty",
        "InstantTimeToEmpty", "Voltage", "Amperage", "InstantAmperage",
        "DesignCycleCount9C", "Manufacturer", "Serial",
    ]
    data = {}
    for k in keys:
        m = re.search(rf'"{k}"\s*=\s*"?([^"\n]+?)"?\s*$', out, re.MULTILINE)
        if m:
            data[k] = _coerce(k, m.group(1))
    return data

def power_info():
    try:
        out = subprocess.check_output(
            ["system_profiler", "-json", "SPPowerDataType"],
            stderr=subprocess.DEVNULL,
        )
        return json.loads(out).get("SPPowerDataType", []) or []
    except Exception as e:
        return [{"_error": str(e)}]

bat = ioreg_battery()
power = power_info()

# Locate the battery health/condition section in SPPowerDataType
condition = None
for section in power:
    name = section.get("_name", "") or ""
    if "battery" in name.lower() or "battery" in str(section.get("sppower_battery_health", "")).lower():
        condition = (
            section.get("sppower_battery_health")
            or section.get("sppower_battery_health_maximum_capacity")
        )
        if condition:
            break
    health = section.get("sppower_battery_health_info") or {}
    if isinstance(health, dict) and health.get("sppower_battery_health"):
        condition = health.get("sppower_battery_health")
        break

design = bat.get("DesignCapacity")
maxcap_raw_field = bat.get("AppleRawMaxCapacity")
maxcap_field = bat.get("MaxCapacity")

def looks_like_pct(x):
    return isinstance(x, int) and 0 <= x <= 100

# Apple Silicon: MaxCapacity may be percentage (≤100). Intel: usually mAh.
# Pick the field that's clearly mAh; never use a percentage as a denominator.
if isinstance(maxcap_raw_field, int) and maxcap_raw_field > 100:
    maxcap_mah = maxcap_raw_field
elif isinstance(maxcap_field, int) and maxcap_field > 100:
    maxcap_mah = maxcap_field
else:
    maxcap_mah = None

current_field = bat.get("AppleRawCurrentCapacity") or bat.get("CurrentCapacity")
if isinstance(current_field, int) and current_field > 100:
    current_mah = current_field
else:
    current_mah = None

def pct(num, den):
    if num and den and den > 0:
        return round(num / den * 100, 2)
    return None

# Max capacity %: prefer the direct field if it's already a percentage, else compute.
direct_pct = maxcap_field if looks_like_pct(maxcap_field) else None
computed_pct = pct(maxcap_mah, design) if (design and design > 100) else None
max_capacity_pct = direct_pct if direct_pct is not None else computed_pct

# Current charge %: prefer direct, else derive (only if both numerator and denom are mAh).
if looks_like_pct(bat.get("CurrentCapacity")):
    charge_pct = bat.get("CurrentCapacity")
elif current_mah and maxcap_mah:
    charge_pct = pct(current_mah, maxcap_mah)
else:
    charge_pct = None

raw_battery_serial = bat.get("Serial")

result = {
    "cycle_count": bat.get("CycleCount"),
    "design_capacity_mah": design if isinstance(design, int) and design > 100 else None,
    "max_capacity_mah": maxcap_mah,
    "current_capacity_mah": current_mah,
    "nominal_charge_capacity_mah": bat.get("NominalChargeCapacity"),
    "max_capacity_pct": max_capacity_pct,
    "charge_pct": charge_pct,
    "fully_charged": bat.get("FullyCharged"),
    "external_connected": bat.get("ExternalConnected"),
    "is_charging": bat.get("IsCharging"),
    "battery_temp_centikelvin": bat.get("Temperature"),
    "voltage_mv": bat.get("Voltage"),
    "amperage_ma": bat.get("Amperage"),  # signed: negative = discharging
    "design_cycle_count": bat.get("DesignCycleCount9C"),
    "manufacturer_code": bat.get("Manufacturer"),  # vendor code (DSY/ATL/SMP), not PII
    "battery_serial_hash": hash_serial(raw_battery_serial),
    "condition": condition,
    # Local-debug only — strip before submission.
    "_raw_ioreg": bat,
    "_raw_power_info": power,
}
if INCLUDE_PLAINTEXT_SERIAL:
    result["battery_serial"] = raw_battery_serial
    result["_warn"] = "plaintext battery serial included by INCLUDE_PLAINTEXT_SERIAL=1; strip before submission"

print(json.dumps(result, indent=2, default=str))
PYEOF
