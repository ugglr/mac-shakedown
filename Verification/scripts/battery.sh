#!/bin/bash
# battery.sh — battery health summary as JSON
# Usage: ./battery.sh

set -euo pipefail

python3 - <<'PYEOF'
import json
import re
import subprocess

SIGNED_KEYS = {"Amperage", "InstantAmperage"}

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
maxcap_raw = bat.get("AppleRawMaxCapacity") or bat.get("MaxCapacity")
current = bat.get("AppleRawCurrentCapacity") or bat.get("CurrentCapacity")
nominal = bat.get("NominalChargeCapacity")

# On Apple Silicon, MaxCapacity may already be a percentage (≤100). Only treat
# it as mAh if it's clearly larger than that.
def looks_like_pct(x):
    return isinstance(x, int) and 0 <= x <= 100

def pct(num, den):
    if num and den and den > 0:
        return round(num / den * 100, 2)
    return None

# If MaxCapacity reads as a percentage directly, surface that. Otherwise compute.
direct_pct = bat.get("MaxCapacity") if looks_like_pct(bat.get("MaxCapacity")) else None
computed_pct = pct(maxcap_raw, design)

# Charge percentage: if CurrentCapacity is small (≤100), it's already %; else derive.
if looks_like_pct(bat.get("CurrentCapacity")):
    charge_pct = bat.get("CurrentCapacity")
else:
    charge_pct = pct(current, maxcap_raw)

result = {
    "cycle_count": bat.get("CycleCount"),
    "design_capacity_mah": design,
    "max_capacity_mah": maxcap_raw if not looks_like_pct(maxcap_raw) else None,
    "current_capacity_mah": current if not looks_like_pct(current) else None,
    "nominal_charge_capacity_mah": nominal,
    "max_capacity_pct": direct_pct if direct_pct is not None else computed_pct,
    "charge_pct": charge_pct,
    "fully_charged": bat.get("FullyCharged"),
    "external_connected": bat.get("ExternalConnected"),
    "is_charging": bat.get("IsCharging"),
    "battery_temp_centikelvin": bat.get("Temperature"),
    "voltage_mv": bat.get("Voltage"),
    "amperage_ma": bat.get("Amperage"),  # signed: negative = discharging
    "design_cycle_count": bat.get("DesignCycleCount9C"),
    "manufacturer": bat.get("Manufacturer"),
    "battery_serial": bat.get("Serial"),
    "condition": condition,
    "raw_ioreg": bat,
    "raw_power_info": power,
}
print(json.dumps(result, indent=2, default=str))
PYEOF
