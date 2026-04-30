---
created: 2026-04-29
tags: [issue, thermal, m5-max]
severity: medium
detectable-on-site: yes
---

# Thermal Throttling — 14" M5 Max

The 14" chassis can't fully cool the M5 Max under sustained heavy workloads. This is a **design constraint**, not a defect — but it's relevant because it overlaps with the [bad-batch issue](Performance%20Variance.md) and you want to distinguish the two.

## Symptoms

- Sustained multi-core workloads cause measurable performance drops within minutes.
- Fan ramps to high RPM aggressively under load.
- Some users report the screen going black / unresponsiveness during intensive tasks until the chassis cools (this is at the defect end of the spectrum).
- Chassis becomes hot to touch around the keyboard / hinge area.

## Normal vs. defective

**Normal:** sustained Cinebench R24 score is ~10–15% below the burst score after the chassis stabilizes. Fans loud but steady. Frequency holds at boost-minus-some after the warmup phase.

**Defective:** sudden frequency cliffs in the first 30s, > 25% sustained drop, or repeated thermal cutouts. Often correlates with [bad-batch issue](Performance%20Variance.md) (uneven thermal paste).

## How to test

1. Cinebench R24 multi-core 10-minute loop, OR `stress-ng --cpu N --timeout 600s` with `powermetrics` logging.
2. Log:
	- CPU package temp every 1s
	- CPU P-core / E-core frequencies
	- Fan RPM (`powermetrics --samplers smc` exposes this)
3. After test:
	- Plot or summarize freq over time
	- Note time-to-first-throttle
	- Note steady-state frequency vs. peak

Healthy 14" M5 Max should hold somewhere around ~70–80% of peak frequency under sustained load after warmup. Cliffs to base clock within seconds of load = problem.

## Mitigations (after purchase, not relevant for verification)

- 16" model has more thermal headroom — different decision, not a fix.
- High Power Mode (System Settings → Battery) keeps fans aggressive, slightly raises sustained perf.

## Sources

- [Notebookcheck — M5 Max review with throttling](https://www.notebookcheck.net/M5-Max-with-inconsistent-performance-and-throttling-issues-Apple-MacBook-Pro-14-Review.1246064.0.html)
- [MacRumors — 14" can't handle Mx Max throttling thread](https://forums.macrumors.com/threads/14-macbookpro-cant-handle-m5-mx-max-throttling-due-to-heating.2479303/)
- [Apple Discussions — slow and overheating](https://discussions.apple.com/thread/256251650)
