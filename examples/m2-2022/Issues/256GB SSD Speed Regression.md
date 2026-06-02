---
created: 2026-06-02
tags: [issue, confirmed, ssd, storage]
severity: medium
detectable-on-site: yes
---

# 256GB Base-SSD Speed Regression (single NAND die vs two)

**The headline M2 defect.** Base 256GB consumer configs ship a single 256GB NAND die where the equivalent M1 256GB models used two 128GB dies in parallel, roughly halving sequential throughput.

## Symptoms

- Sequential read/write roughly halved vs the M1 256GB it replaces.
- Measured ~1,431-1,500 MB/s on M2 256GB vs ~2,733-2,900 MB/s (write) and ~2,854-4,900 MB/s (read) on M1 256GB.
- Real-world impact shows up on large-file copies, big media exports, and swap-heavy workloads when RAM is exhausted. Most light users will not notice.

## Suspected cause

- Apple consolidated storage onto a single higher-density 256GB NAND die instead of two 128GB dies, removing the dual-channel parallelism that gave the M1 256GB models their speed.
- Confirmed via teardowns (9to5Mac, Max Tech) showing one flash chip where M1 had two.
- This is permanent for the affected unit: M2 storage is soldered and non-upgradeable. Apple acknowledged the benchmark difference (told The Verge real-world is still faster overall) and reverted to dual NAND on the M3 Air, which retroactively confirms the regression was real.

## Affected scope

- Base 256GB configs of MacBook Air 13" M2 (2022), MacBook Air 15" M2 (2023), MacBook Pro 13" M2 (2022), and Mac mini M2 (2023).
- 512GB+ configs are unaffected (they use multiple dies).
- M2 Pro/Max/Ultra machines do not ship a 256GB tier and use multiple dies, so they are not affected by this specific issue.

## How to detect on-site

**Phase 11 (SSD test)** surfaces this directly. The sequential read/write benchmark hits the ~1,400-1,600 MB/s ceiling on a single-die 256GB drive instead of the ~2,700-3,000+ MB/s of a multi-die unit. Cross-check storage capacity in About This Mac: only 256GB SKUs are affected.

**Calibration note:** do not fail a 256GB M2 unit for ~1,450 MB/s. That is the expected (defective-by-design) baseline for this SKU, not a faulty drive. Thresholds should branch on capacity:
- 256GB M2: expected ~1.4-1.6 GB/s
- 512GB+: expected ~2.9-3.2 GB/s and up

A 256GB unit benchmarking well below ~1.4 GB/s, on the other hand, would suggest a genuinely failing drive.

## Sources

- [MacRumors: M2 MacBook Air slower SSD in base model](https://www.macrumors.com/2022/07/14/m2-macbook-air-slower-ssd-base-model/)
- [MacRumors: M2 Mac mini 256GB slower SSD](https://www.macrumors.com/2023/01/24/m2-mac-mini-256gb-slower-ssd/)
- [MacRumors: 15-inch MacBook Air single 256GB chip](https://www.macrumors.com/2023/06/13/15-inch-macbook-air-single-256gb-chip/)
- [9to5Mac: M2 MacBook Air slower SSD in base model](https://9to5mac.com/2022/07/14/m2-macbook-air-slower-ssd-base-model/)
- [Macworld: 15-inch Air 256GB single-NAND storage](https://www.macworld.com/article/1953645/15-inch-macbook-air-256gb-storage-nand-chip.html)
- [MacRumors: M2 MacBook Air teardown (single storage chip)](https://www.macrumors.com/2022/07/18/macbook-air-m2-chip-teardown/)
