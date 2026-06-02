---
created: 2026-06-02
tags: [issue, anecdotal, thermal, single-source]
severity: low
detectable-on-site: only-with-benchmarks
---

# 13-inch MacBook Pro M2 Severe Sustained Thermal Throttling

Single-source but documented: the 13" M2 MacBook Pro, which reused the older Touch Bar single-fan chassis, throttles hard under extreme sustained load. Every outlet traces to one Max Tech test on one unit running an 8K Canon RAW export. Hardware Unboxed and Gary Explains could not reproduce it. Partly expected design behavior for a thermally-constrained chassis, not a confirmed defect.

## Symptoms

- Under prolonged maximum load (8K Canon RAW export), the chip hit ~108C.
- P-cores throttled from ~3,200 MHz to ~1,894 MHz; the GPU collapsed from ~1,393 MHz to ~289 MHz.
- Single fan pinned at ~7,200 RPM, clocks oscillating as temps cycled between ~108C and ~84C.
- Package power dropped from ~29.5W to ~7.3W as it throttled.

## Suspected cause

- M2 placed in the carried-over 13" single-fan thermal design with no temperature cap on the SoC. The cooling cannot dissipate sustained peak power, so the chip throttles hard once saturated.
- The better-cooled dual-fan 14"/16" M2 Pro/Max did not show this.
- This is a documented limitation of one model under one extreme workload (the most demanding test Max Tech runs), far outside normal use for a $1,299 13" laptop. The same outlets recommend that 8K editors simply buy the 14".

## Affected scope

- MacBook Pro 13" M2 (2022) only, the model that reused the older Touch Bar single-fan chassis.
- Not the 14"/16" M2 Pro/Max (dual-fan, well cooled).

## How to detect on-site

**Phase 5 (sustained thermal load)** plus **Phase 4 (CPU variance)**. The long sustained-load phase is designed to surface exactly this thermal cliff; the variance phase may show wide score spread as clocks oscillate.

- Run a sustained CPU/GPU stress for 10-20 minutes while logging clock speed and die temperature.
- Watch for large, sustained clock drops and temps near ~100-108C on the 13" M2 specifically.
- A short burst will look fine. The cliff appears only after thermal saturation.

**Calibration note:** this is partly expected for the 13" M2's weak chassis under extreme loads. Flag only if throttling is more severe than the chassis baseline or temps are abnormal vs peers. Use this as an extreme-sustained-load data point, not as a general M2 defect.

## Sources

- [iMore: M2 MacBook Pro hits 108C and exposes severe throttling](https://www.imore.com/m2-macbook-pro-hits-108-degrees-c-and-exposes-severe-throttling)
- [Tom's Guide: MacBook Pro M2 reportedly suffers from severe throttling](https://www.tomsguide.com/news/macbook-pro-m2-reportedly-suffers-from-severe-throttling-what-you-need-to-know)
- [Digital Trends: Apple M2 MacBook Pro hits 108 degrees Celsius](https://www.digitaltrends.com/computing/apple-m2-macbook-pro-hits-108-degrees-celsius/)
- [mjtsai: M2 Mac thermal concerns (aggregator with counter-evidence)](https://mjtsai.com/blog/2022/07/05/m2-mac-thermal-concerns/)
- [Hacker News: Severe thermal throttling discovered in Apple's M2 MacBook Pro](https://news.ycombinator.com/item?id=31941326)
