---
created: 2026-04-29
tags: [issue, battery, m5]
severity: medium
detectable-on-site: partial
---

# Battery Defects

Reports of significantly worse-than-advertised battery life on a subset of M5 / M5 Pro units, suspected to be a manufacturing defect on specific production runs from late 2025 / early 2026.

## Symptoms

- 8 hours max with light use (Safari + ChatGPT + Pages + Spotify), well below the rated ~22h.
- Reviewers note the Pro / Pro 14" doesn't hit the numbers in launch reviews.
- High idle drain reported on some units.

## How to detect on-site

Hard to fully verify in 30 minutes because real-world battery is a multi-hour test. Best you can do:

1. **Battery health %.** Fresh unit should be 100%, ≤ 1 cycle.
	`system_profiler SPPowerDataType | grep -A 5 "Battery Information"`
	Or: System Settings → Battery → Battery Health.

2. **Cycle count.** Should be 0 or 1.
	`ioreg -l | grep -i CycleCount`

3. **Designed vs. current capacity.** Should match exactly on a new unit.
	`ioreg -l -w 0 | grep -i "DesignCapacity\|MaxCapacity"`

4. **Idle drain test (~30 min).** Display sleep, no apps running, measure delta. Charge to 100%, unplug, leave for 30 min, check %. The harness flags > 5% drain as warn and > 10% as fail (see [Pass-Fail Criteria](../../../Verification/Pass-Fail%20Criteria.md#optional-idle-drain)). On a known-clean unit, expect 1–3% drain over 30 min sleep. Anything above ~5% is worth investigating.

5. **Quick load discharge.** Run the sustained CPU benchmark from the [performance test](Performance%20Variance.md) on battery and watch the drain rate. Compare to published full-load runtime.

What you **can't fully verify on-site:** advertised hour totals on real workloads. That's a full-day test. But the battery health stats + idle drain + load drain rate together are a strong proxy.

## Sources

- [Apple Discussions: Bad battery life on M5 MBP](https://discussions.apple.com/thread/256215660)
- [Technobezz: M5 Pro battery draining fast fix](https://www.technobezz.com/macbook-pro-14-m5-pro-battery-draining-fast-fix)
- [iFixit: Crazy battery replacement procedure on M5 MBP](https://www.ifixit.com/News/114046/m5-macbook-pro-teardown)
