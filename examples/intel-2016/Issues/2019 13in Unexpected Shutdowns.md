---
created: 2026-06-02
tags: [issue, power, firmware]
severity: medium
detectable-on-site: no
---

# 2019 13" Two-Port Unexpected Shutdowns

Apple-acknowledged unexpected shutdowns on the entry-level two-port 2019 13" MacBook Pro, addressed via a procedural battery-conditioning workaround.

## Symptoms

- Unit unexpectedly shuts down or will not power on normally.
- In some reports it shuts down with battery charge remaining (users reported shutdowns at 35-45% remaining).

## Suspected cause

Not publicly disclosed by Apple, and widely treated as a power-management or firmware issue. Apple's remedy was a procedural battery-conditioning workaround (drain below 90%, charge 8 hours while asleep, update macOS) followed by service if it persisted, which suggests a firmware/battery-controller cause rather than a fixed hardware recall.

## Affected scope

Entry-level 13-inch MacBook Pro 2019 with TWO Thunderbolt 3 ports (the lower-tier 2019 13", released July 2019). Acknowledged by Apple in a December 2019 support document. Narrow scope (one lower-tier SKU), non-data-destructive, addressed via a documented workaround and service path rather than a safety recall.

## How to detect on-site

This is **not reliably detectable by the harness**. Phase 2 battery and Phase 9 idle-drain may surface an abnormal battery or power profile, but the shutdown itself is intermittent. The practical screen is mostly **manual Phase 1 SKU identification plus a macOS-version check**: confirm the SKU (2019 13" two-port), ensure macOS is current, check for prior unexpected-shutdown / power logs, and confirm the unit holds power under light use.

## Sources

- [MacRumors: MacBook Pro 2019 unexpected shutdowns](https://www.macrumors.com/2019/12/03/macbook-pro-2019-unexpected-shutdowns/)
- [Macworld: what to do if your 2019 13" MacBook Pro randomly shuts down](https://www.macworld.com/article/3488496/what-to-do-if-your-new-2019-13-inch-macbook-pro-randomly-shuts-down.html)
- [Laptop Mag: 13" MacBook Pro bug causes random shutdowns, here's a fix](https://www.laptopmag.com/news/critical-13-inch-macbook-pro-bug-causes-random-shutdowns-heres-a-fix)
- [Tom's Guide: Apple admits MacBook Pros are randomly shutting down](https://www.tomsguide.com/news/apple-admits-macbook-pros-are-randomly-shutting-down-heres-what-to-do)
