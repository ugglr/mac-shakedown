---
created: 2026-06-02
tags: [verification, benchmarks, reference]
---

# Benchmark Reference

Shakedown's own thresholds are not yet calibrated against confirmed-good hardware, and its default workload (SHA-256) is hardware-accelerated, so the harness is a structured *consistency* check, not an absolute pass/fail. Published third-party benchmarks fill the other half: an absolute floor your unit should clear when cool, plus a crowd-sourced distribution of real units you can compare against. This is the "install this, run this, your unit should score about X" companion to the [Runbook](Runbook.md), tuned for catching a bad unit (the M5 Max especially) in a store you cannot easily return to.

> In a hurry at the counter? The [Store Day Checklist](Store%20Day%20Checklist.md) is the short, top-to-bottom run-this-then-that version. This page is the detailed reference behind it (expected scores, sources, caveats).

Use it alongside the harness:
- `./run --store` runs the thorough profile (both CPU workloads, GPU, longer warmup, more iterations) for the structured variance and thermal verdict.
- `compare-reports.sh REFERENCE.json UNIT.json` diffs your unit against a known-good sibling, which is the most trustworthy signal while the absolute thresholds are uncalibrated.

## How to read these numbers

- **The links are the source of truth, the printed numbers are a snapshot.** Scores drift with macOS releases, firmware/SMC updates, ambient temperature, power mode, and config, and crowd averages move as submissions land. Re-check the live link for your exact SKU. Treat a printed range as a healthy floor the machine should reach when cool, not a target it must hold under sustained load.
- **Single-core is the cleanest tell.** It barely varies with cooling, chassis, or bin, so a single-core result more than ~5-7% below the band is the most reliable red flag for a real defect, a rebinned/wrong chip, background load, or a bad power mode. Multi-core is weaker evidence on its own: it swings with cooling, power mode, and core-count bin, so confirm you are comparing the right bin first.
- **Compare same chip AND same core-count bin AND same chassis.** A 14" M5 Max legitimately throttles well below a 16" by design. A fanless Air tapers under sustained load by design. Neither is a defect.
- **Benchmark hygiene.** "CB R24" here means Cinebench 2024 (Maxon dropped the "R"). Do not mix it with the older Cinebench R23 (Intel-era user reports, different scale) or with Macworld's Cinebench 2026 (a different benchmark again).
- **Confidence tiers:** *well-sourced* = cross-confirmed against primary sources; *rough* = real but thin or internally disagreeing, verify live; *look up live* = no trustworthy published number, do not trust a printed figure.

## Tools (no Terminal or Xcode needed)

- **Geekbench 6** (CPU and Metal GPU). Point-and-click, installs in a couple of minutes. The single biggest sample of real Mac scores.
- **Cinebench 2024** (Maxon). The sustained-loop test: it has a minimum-test-duration / loop mode that heat-soaks the chassis, which is what actually surfaces the M5 defect.
- **[mianibench.com](https://mianibench.com/)** (crowd-sourced, Apple-only). Real-world Cinebench plus Blender, Final Cut, DaVinci Resolve, and Cyberpunk results, filterable by chip series (M1 to M5) and variant (Standard / Pro / Max / Ultra). This is the best *distribution* view: it shows the spread of real units of your exact SKU, so you can see whether yours is a normal sample or a low outlier. That outlier check is the comparison the harness can't do on its own. (Aggregated views may want a free account; it is a browser app.)
- **Apple Diagnostics** (hold D, or Option-D, at power-on). Apple's own logic-board / sensor / fan / power self-test, with a reference code you can show staff.
- A browser display tester ([screentest.run](https://screentest.run/), [oledtest.org](https://oledtest.org/)) for dead/stuck pixels and bleed.

## Live lookup (check your exact SKU before relying on anything)

- [Geekbench 6 Mac benchmarks](https://browser.geekbench.com/mac-benchmarks): per-model averages, the live yardstick. Open in a normal browser (the pages 403 automated fetches).
- [mianibench.com Cinebench](https://mianibench.com/benchmark/1): crowd-sourced distribution by chip + variant.
- [Notebookcheck M5 Max](https://www.notebookcheck.net/Apple-M5-Max-Processor-Benchmarks-and-Specs.1244918.0.html) and the [M5 Pro / M5 Max CPU analysis](https://www.notebookcheck.net/Apple-M5-Pro-M5-Max-CPU-Analysis-M5-Max-is-not-much-faster-than-the-M4-Max.1246054.0.html) (includes the 16" vs 14" split).
- [MacRumors M5 Max leak](https://www.macrumors.com/2026/03/05/m5-max-geekbench-benchmarks/): GB6 single ~4,268 / multi ~29,233.

## Reference scores by generation

Cinebench numbers are Cinebench 2024 / R24. Geekbench numbers are Geekbench 6. Ranges are real samples, not targets.

### Apple M5 family (2025-2026)

Compare same chassis only: the 14" M5 Max legitimately throttles well below the 16" by design.

| SKU | CB R24 multi | GB6 multi | GB6 single | Confidence |
|---|---|---|---|---|
| M5 (base, 10-core) MBP 14" / Air / iPad Pro | ~957-1,172 (MBP 14" tops the band, Air lower) | ~16,500-18,050 | ~4,130-4,330 | well-sourced |
| M5 Pro (18-core) MBP 14"/16" | ~2,347 (one 16" sample, approximate) | ~28,436 (thin samples) | ~4,295 | rough, verify live |
| **M5 Max (18-core CPU, 40-core GPU) MBP 16"** | **~2,073-2,437** (16" ~2,437, 14" ~2,073) | **~29,000-29,415** | **~4,200-4,335** | well-sourced |

### Apple M4 family (2024-2025)

| SKU | CB R24 multi | GB6 multi | GB6 single | Confidence |
|---|---|---|---|---|
| M4 (10-core) MBA / mini / iMac / MBP 14 base | ~815-986 (fanless Air lower) | ~14,650-15,200 | ~3,650-3,840 | well-sourced |
| M4 Pro (12-core) mini / MBP 14 | ~1,400-1,460 | ~20,300-20,700 | ~3,830-3,930 | well-sourced |
| M4 Pro (14-core) mini / MBP 14/16 | ~1,660-1,750 | ~22,400-22,600 | ~3,830-3,930 | well-sourced |
| M4 Max (14-core, 32-GPU) MBP 14/16 | ~1,700-1,800 (look up live) | ~22,000-23,500 (look up live) | ~3,850-3,950 | look up live |
| M4 Max (16-core, 40-GPU) MBP 14/16 | ~2,000-2,100 | ~25,600-26,700 | ~3,880-4,060 | well-sourced |

### Apple M3 family (2023-2024)

Single-core is near-flat family-wide (~3,050-3,160 GB6), so it is a health check, not a SKU differentiator.

| SKU | CB R24 multi | GB6 multi | GB6 single | Confidence |
|---|---|---|---|---|
| M3 8-core (cooled) MBP 14 / iMac / mini | ~590-712 (treat ~600 as typical) | ~11,700-12,100 | ~3,000-3,130 | well-sourced |
| M3 8-core (fanless) MacBook Air | look up live (~580-600, then throttles) | ~11,500-12,100 | ~3,000-3,160 | look up live |
| M3 Pro 11-core | ~900-960 | ~14,000-14,500 | ~3,080-3,130 | well-sourced |
| M3 Pro 12-core | ~1,000-1,080 | ~15,000-15,500 | ~3,090-3,140 | well-sourced |
| M3 Max 14-core (30-GPU) | ~1,350-1,510 | ~18,500-19,000 | ~3,050-3,150 | well-sourced |
| M3 Max 16-core (40-GPU) | ~1,530-1,660 | ~20,900-21,300 | ~3,090-3,160 | well-sourced |

### Apple M2 family (2022-2023)

| SKU | CB R24 multi | GB6 multi | GB6 single | Confidence |
|---|---|---|---|---|
| M2 (8-core) MBA / MBP 13 / mini | ~555-600 | ~9,600-9,750 | ~2,580-2,650 | well-sourced |
| M2 Pro 10-core base MBP 14 / mini | look up live (~640-680) | ~12,300-12,900 | ~2,640-2,670 | rough |
| M2 Pro 12-core MBP 14/16 / mini | ~780-800 | ~14,400-14,600 | ~2,650-2,665 | well-sourced |
| M2 Max (12-core) MBP 14/16 / Studio | ~1,030-1,070 | ~14,600-14,900 | ~2,700-2,750 | well-sourced |

### Apple M1 family (2020-2021)

| SKU | CB R24 multi | GB6 multi | GB6 single | Confidence |
|---|---|---|---|---|
| M1 (8-core) MBA / MBP 13 / mini / iMac 24 | ~444-525 | ~8,200-8,650 | ~2,320-2,370 | well-sourced |
| M1 Pro 8-core MBP 14 base | ~628 | ~10,314 | ~2,360 | well-sourced |
| M1 Pro 10-core MBP 14/16 | ~824 | ~12,250-12,360 | ~2,370-2,390 | well-sourced |
| M1 Max 10-core MBP 14/16 / Studio | ~796 | ~12,277-12,661 | ~2,376-2,419 | well-sourced |

### Intel MacBook Pro 16" (Late 2019)

9th-gen Coffee Lake-H. Geekbench 6 (14k-16k Mac-specific samples) is the trustworthy yardstick. Cinebench R24 data for these chips is sparse, largely non-Mac, and internally inconsistent, so it is look-up-live only.

| SKU | CB R24 multi | GB6 multi | GB6 single | Confidence |
|---|---|---|---|---|
| i7-9750H (6-core) base | look up live | ~5,000-5,500 | ~1,280-1,320 | well-sourced (GB6) |
| i9-9880H (8-core) common | look up live | ~6,000-6,500 | ~1,330-1,380 | well-sourced (GB6) |
| i9-9980HK (8-core) top BTO | look up live | ~6,200-6,700 | ~1,350-1,400 | rough |

## Spotting a bad unit

Three independent signals separate a good unit from a bad one. Weigh all three; a single low number is not proof.

1. **Score vs baseline (single-core is the cleanest tell).** Run Geekbench 6 and Cinebench 2024 once on a cool, plugged-in machine and compare to the matching SKU row. A single-core result more than ~5-7% below the band is the most reliable red flag. A multi-core result 15-20%+ below baseline with no explanation (an M5 Max 16" under ~23-24k GB6 multi, an M4 Max under ~20k, an Intel i9-9880H near 5,000) is suspect once you have confirmed the bin.
2. **Run-to-run variance.** Run the benchmark 3-5 times back to back from a cold start. For the M5 Max specifically, run GB6 multi 5 times with ~30 s gaps and compute `(max - min) / mean`; flag if the spread exceeds ~10%. Healthy units cluster within a few percent and single-core varies only ~1-2%. Wild swings on a cool machine are the headline early-M5-Max bad-batch signature (reported up to ~41.5%), and they show in multi-core, not single.
3. **Drop under sustained heat (the most important test).** Loop Cinebench 2024 multi-core for ~10+ minutes and watch the score per pass. Normal: the sustained score settles ~10-15% below the cold-burst peak after the first 1-2 runs, then HOLDS steady with loud-but-steady fans. Not acceptable: a continuous downward staircase, a plateau far below the SKU band, fans pinned at max while the score still collapses, or a thermal shutdown / kernel panic. That monotonic decay is the signature of bad paste, poor heatsink contact, a weak fan, or a thermal-sensor fault.

**SKU sanity check:** confirm System Information reports the advertised CPU and core/thread count. An M3 Max scoring like an M3 Pro, or a "9980HK" reporting 6 cores, is a relabeled or wrong unit. Walk away.

**Do not false-flag:** fanless Airs (M1-M4) and the 14" M5 Max throttle under sustained load by design. Always compare same chip, same bin, same chassis. If a fan-equipped Pro throttles like a fanless Air, the cooling is suspect.

## In the store (~15-20 min, catch the obvious before you leave)

Cheapest and most decisive reads first, then one quick baseline, then a fast cosmetic sweep.

1. **Power and Wi-Fi.** Plug into the AC charger (sustained benchmarks need wall power) and join store Wi-Fi.
2. **Instant battery read.** Option-click the Apple menu, then System Information, then Power. Cycle Count should be 0-2 and Condition Normal. High cycles or "Service Recommended" on a "new" unit is a reject.
3. **Apple Diagnostics.** Shut down, hold D at power-on. 2-5 min, surfaces logic-board / sensor / fan / power faults with a code you can show staff.
4. **Install Geekbench 6 + Cinebench 2024** while diagnostics run (GUI apps, no Terminal).
5. **One baseline run each.** Write down the numbers and compare to the SKU row above and to mianibench / Geekbench Browser. One pass does not clear a unit, but it catches an instant failure and gives a reference.
6. **Cosmetic + I/O sweep.** Lid/chassis creak, every port, both speakers, a solid-color display sweep for dead/stuck pixels, and listen for coil whine during the benchmark.
7. **The sibling control (highest leverage).** Benchmark a floor/demo unit of the SAME model and config under the same ambient. The defect is unit-level, so an A/B against a known-good twin is the cleanest judge: yours should land within a few percent on both single-run and sustained scores. Put the two panels side by side on the same test image.
8. **If anything is clearly off, exchange it right there** before leaving the counter.

## That night at the hotel (the real test, still in the city)

The 15-20 min store window cannot run a sustained loop. Do it that night, on AC, on a hard flat surface in a cool room.

1. **Harness, thorough profile:** `SHAKEDOWN_YES=1 ./run --store` (it auto-selects the preset for your hardware; add `--target <name>` to pin one). Both CPU workloads (including the non-accelerated BLAKE2b that matches where the defect was reported), the GPU pass, a long warmup, and 8 iterations. Rerun any single WARN.
2. **Sustained Cinebench loop:** Cinebench 2024 multi-core back to back for ~30-45 min (or its minimum-test-duration mode). Record EACH run's score. A healthy unit settles to a stable sustained score; a defective one keeps sagging run-over-run. Infant-mortality and batch-variance defects often pass a cold first run and only show by the 3rd-4th run under heat.
3. **Second workload:** re-run Geekbench 6 (CPU and Metal) a few times against the live Geekbench Browser average for your exact model.
4. **Compare against a sibling** if you captured one: `./Verification/scripts/compare-reports.sh sibling.json yours.json`.
5. **Unhurried display + I/O:** dark-room black/white/grey/RGB fields for pixels and bleed, every key, Touch ID, every port in both orientations, MagSafe, headphone jack, trackpad corners, speakers at volume, mics, webcam, Wi-Fi/Bluetooth range.
6. **If the night test reveals a defect**, you still have the next in-city day to exchange it. Keep the receipt and packaging until the unit fully passes.

## Hong Kong return constraint (this drives the whole protocol)

Apple Hong Kong retail purchases are effectively exchange-only and only for an Apple-verified defect (no change-of-mind returns), with at most a 14-day defective-exchange window and original receipt + packaging required. A bad unit has to be caught and exchanged **while you are still in Hong Kong**, ideally before leaving the store. After you fly out there is no easy return, only AppleCare warranty repair. Leave at least one buffer day in the city, and keep the receipt and all packaging until the unit has passed the night test.

> Every printed score above is advisory and drifts over time. Confirm the SKU and core count, compare same chip / same bin / same chassis, prefer an A/B against a known-good sibling, and weigh all three signals (vs-baseline, run-to-run variance, sustained-load trend) together before rejecting a unit. The live-lookup links, not these numbers, are the truth.
