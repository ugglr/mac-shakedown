---
created: 2026-06-02
tags: [issue, confirmed, ssd, storage, m2-pro]
severity: low
detectable-on-site: yes
---

# 512GB M2 Pro SSD Regression (two 256GB dies vs four 128GB)

A separate, lower-impact storage regression on the 512GB M2 Pro tier: two 256GB NAND dies where the 512GB M1 Pro used four 128GB dies, dropping peak read throughput by roughly 40%. Distinct from the 256GB consumer issue.

## Symptoms

- Sequential speeds noticeably below the 512GB M1 Pro it replaces.
- 14" M2 Pro 512GB measured ~2,973 MB/s read / ~3,154 MB/s write (Blackmagic) vs M1 Pro 512GB ~4,900 MB/s read / ~3,951 MB/s write. AJA showed M2 Pro ~2,703 read / ~2,929 write vs M1 Pro ~4,081 / ~3,450.
- Still fast in absolute terms. Impact is mostly on read-heavy large-file work.

## Suspected cause

- Halving the NAND die count (four 128GB to two 256GB) on the 512GB tier reduces channel parallelism, dropping peak read throughput.
- Confirmed by the 9to5Mac teardown (fewer visible flash packages: one on the M2 Pro front vs two front plus two back on the M1 Pro per iFixit) and by AJA/Blackmagic benchmarks. Original benchmark numbers trace to @ZONEofTECH, replicated by 9to5Mac and others.
- Higher tiers (1TB+) are on par or faster than the M1 equivalents.

## Affected scope

- 512GB configuration of the 14" and 16" MacBook Pro M2 Pro (2023), and the M2 Pro Mac mini 512GB.
- The MacBook Pro 512GB comparison is the clean, well-corroborated one. For the Mac mini the comparison is muddier because there was no M1 Pro Mac mini to compare against, so lean on the MacBook Pro framing for the mini portion.

## How to detect on-site

**Phase 11 (SSD test)** surfaces the lower read ceiling. On a 512GB 14"/16" M2 Pro, read lands near ~2,700-3,000 MB/s rather than the ~4,000-4,900 MB/s of the M1 Pro. Compare against a known M1 Pro 512GB if one is available.

**Calibration note:** the 512GB M2 Pro's ~2.9-3.0 GB/s read is the expected baseline for this SKU and should not be flagged as a failing drive. Flag only if speeds fall well below this (for example dropping toward the 256GB single-die range), which would suggest a genuinely faulty unit.

## Sources

- [Tom's Hardware: MacBook Pro M2 Pro and Mac mini SSD downgrade](https://www.tomshardware.com/news/macbook-pro-m2-pro-mac-mini-ssd-downgrade)
- [9to5Mac: MacBook Pro SSD performance drop (originating teardown)](https://9to5mac.com/2023/01/24/macbook-pro-ssd-performance-drop/)
- [Macworld: SSD speeds on M2 MacBook Pro and Mac mini](https://www.macworld.com/article/1483183/ssd-speeds-m2-macbook-pro-mac-mini.html)
- [NotebookCheck: 14" 512GB M2 Pro ~40% slower SSD than M1 Pro](https://www.notebookcheck.net/MacBook-Pro-14-512-GB-with-M2-Pro-apparently-has-a-40-slower-SSD-than-its-M1-Pro-predecessor.685368.0.html)
- [MacRumors: M2 Mac mini 256GB slower SSD (also covers 512GB MBP)](https://www.macrumors.com/2023/01/24/m2-mac-mini-256gb-slower-ssd/)
