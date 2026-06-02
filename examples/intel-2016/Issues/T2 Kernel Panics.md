---
created: 2026-06-02
tags: [issue, t2, firmware, kernel-panic]
severity: medium
detectable-on-site: no
---

# T2 / bridgeOS Kernel Panics on Sleep / Wake

Random kernel panics on T2 Macs, frequently on wake-from-sleep, traced to a bridgeOS firmware bug. Affects a minority of units, not all.

## Symptoms

- Random kernel panics or hard reboots, frequently on wake-from-sleep.
- Sometimes with a "panic ... bridgeOS" string in the report.
- Some users see it daily, others never.

## Suspected cause

A T2 firmware (bridgeOS) bug interacting with sleep and power management. Reported triggers include waking from sleep with no peripherals, Thunderbolt 3 daisy-chaining, TB3-to-TB2 adapters, FileVault, Power Nap, Secure Boot, Apple Watch unlock, and third-party kexts. Partially mitigated by later macOS/bridgeOS updates but not fully eliminated for all users. AppleInsider's service data (4 of 103 iMac Pro warranty repairs) and the fact that clean reinstalls fixed those cases point toward software conflict and per-unit issues rather than a universal hardware defect. Note: not every sleep panic on these machines is T2-related (the 10.15.4 16" 2019 wake panic cited IOGraphicsFamily, a likely separate graphics-sleep bug).

## Affected scope

All T2 Macs in scope: MacBook Pro 2018-2019, MacBook Air 2018-2019, Mac mini 2018, iMac Pro 2017. The issue class is genuinely T2-wide, but the model breadth beyond the 2018 MBP Touch Bar and iMac Pro rests largely on user-forum reports. Reported as a minority of units, not universal.

## How to detect on-site

This is **not reliably detectable by the harness**. The closest automated coverage is manual Phase 8 (Apple Diagnostics) plus a manual sleep/wake during Phase 7/9, but a single short session rarely reproduces it. The practical screen is a Console panic-log check: a unit with a history of bridgeOS panics in its logs is a yellow flag. Recommend adding a Console panic-log check to the manual checklist for T2 units, and letting the unit sleep and wake at least once during the session.

## Sources

- [Notebookcheck: T2 chip causing kernel panics in a few 2018 MacBook Pros and iMac Pros](https://www.notebookcheck.net/Apple-T2-chip-causing-kernel-panics-in-few-2018-MacBook-Pros-and-iMac-Pros.318532.0.html)
- [9to5Mac: 2018 MacBook Pro kernel panics PSA](https://9to5mac.com/2018/07/26/2018-macbook-pro-kernel-panics/)
- [AppleInsider: T2 chip could be behind a small number of crashes](https://appleinsider.com/articles/18/07/26/apples-t2-chip-could-be-behind-small-number-of-crashes-in-imac-pro-new-macbook-pro)
- [Mr. Macintosh: Apple pulls 2019-004 updates after kernel panics](https://mrmacintosh.com/apple-pulls-2019-004-high-sierra-and-sierra-security-updates-after-kernel-panics/)
- [Mr. Macintosh: 10.15.4 wake-from-sleep panic on 16" 2019 MBP](https://mrmacintosh.com/10-15-4-update-wake-from-sleep-kernel-panic-in-16-mbpro-2019/)
