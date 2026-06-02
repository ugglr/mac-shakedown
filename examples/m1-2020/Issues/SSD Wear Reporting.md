---
created: 2026-06-02
tags: [issue, ssd, smart, reporting-artifact]
severity: low
detectable-on-site: no
---

# Excessive SSD Writes / High TBW From Swap (Largely a SMART Reporting Error)

The famous "M1 SSDs are wearing out" scare. Confirmed across multiple outlets, and confirmed to be primarily a SMART reporting error that Apple corrected in macOS Big Sur 11.4, not accelerated physical NAND death. Treat this as buyer context, not a defect.

## Symptoms

- Third-party SMART tools (for example smartmontools) showed alarming "Percentage Used" / data-written growth: some units reportedly consumed 10-13% of the SSD's rated TBW within months, and one 256GB user extrapolated reaching max TBW in ~2 years.
- Often accompanied by incorrect uptime statistics in the same tools.

## Suspected cause

Two competing explanations, with the reporting-error account dominant. Apple's, via an AppleInsider source: a data-reporting error in the SMART monitoring stack, not real accelerated wear. macOS Big Sur 11.4 (released May 24, 2021) corrected both the wear figures and the uptime reporting. The community theory: aggressive memory swapping to SSD on low-RAM (8GB) configs genuinely writing more data. The best evidence supports the reporting-error explanation as dominant. Real swap writes exist, and some developers disputed the pure-reporting-error characterization, but the drives were not dying, and conservative vendor TBW ratings make it unlikely to kill the drive in its useful life. Severity is low: a reporting artifact corrected by software.

Note the date: macOS Big Sur 11.4 shipped May 24, 2021. The June 4, 2021 date that appears in some coverage is when AppleInsider published the fix story.

## Affected scope

All M1 (2020) Macs running early Big Sur: MacBook Air M1, MacBook Pro 13" M1, Mac mini M1. Reports skewed toward 8GB RAM / 256GB SSD configs. Corrected in macOS Big Sur 11.4.

## How to detect on-site

Not directly a pass/fail in the harness. **Phase 11 (SSD sequential test)** measures throughput (read/write MB/s), not endurance/TBW, so it would catch a degraded or slow SSD but not the wear level. Wear/TBW needs a SMART read: a **Phase 1/3 inventory** could surface the SSD model and, if extended, the smartctl "Percentage Used", but this is informational only. On a modern macOS (well past 11.4) the figures are trustworthy. Very high Percentage Used on a low-hour machine would be a real concern, so cross-check against power-on-hours, but do not treat moderate TBW as a defect: contextualize against age and the 11.4 fix.

## Sources

- [MacRumors: M1 Mac users report excessive SSD wear](https://www.macrumors.com/2021/02/23/m1-mac-users-report-excessive-ssd-wear/)
- [AppleInsider: Apple resolves M1 Mac SSD storage longevity issue in macOS 11.4 beta](https://appleinsider.com/articles/21/06/04/apple-resolves-m1-mac-ssd-storage-longevity-issue-in-macos-114-beta)
- [9to5Mac: M1 Mac SSD wear](https://9to5mac.com/2021/03/11/m1-mac-ssd-wear/)
- [Macworld: Apple Silicon M1 SSD read/write excessive data terabytes](https://www.macworld.com/article/334275/apple-silicon-m1-macbook-mac-mini-ssd-read-write-excessive-data-terabytes.html)
- [TechRadar: macOS 11.4 apparently fixes reported SSD wear issue in M1 Macs](https://www.techradar.com/news/macos-114-apparently-fixes-reported-issue-with-ssd-wear-in-m1-macs)
- [Tom's Hardware: Apple fixes SSD wear-out reporting issues](https://www.tomshardware.com/news/apple-fixes-ssd-wear-out-reporting-issues)
