---
created: 2026-06-02
tags: [issue, sd-card, m1-pro-max, firmware]
severity: low
detectable-on-site: manual-inspection
---

# SD Card Reader Misbehavior on 2021 14"/16" MacBook Pro

The reintroduced SD card slot on the 2021 14"/16" MacBook Pro misbehaving: cards not recognized, slow reads, or temporary inaccessibility. Confirmed across multiple outlets. Non-fatal, workaround-able, and software-resolved for most.

## Symptoms

- Some SD cards not recognized at all, others read very slowly.
- Random crashes/inaccessibility, or cards becoming temporarily inaccessible (sometimes taking minutes to appear, with Finder crashes).
- Inconsistent across cards, with no clear pattern of which cards fail (a card that works always works, one that fails always fails; reformatting, capacity, and brand made no reliable difference).

## Suspected cause

A firmware/driver issue in the SD card controller stack. Apple reportedly told some users via support that a software fix was coming, though it never issued a formal public acknowledgment or recall, and the fix rolled into general macOS updates (12.2 / 12.2.1 resolved it for most) rather than a dedicated firmware patch. The workaround is an external USB SD reader dongle. Not a logic-board hardware defect for most, though some users saw residual flakiness on later macOS.

## Affected scope

MacBook Pro 14" and 16" (2021, M1 Pro/Max) with the reintroduced SD card slot.

## How to detect on-site

Maps to **manual Phase 7 (functional inspection)**; **Phase 3 (inventory)** could note the card-reader controller presence. Not automated. Insert a known-good SD/UHS-II card, confirm it mounts, and run a read/write speed test. Try more than one card, since the behavior is card-dependent.

## Sources

- [MacRumors: some SD cards not working properly with 2021 14" and 16" MacBook Pros](https://www.macrumors.com/2021/12/06/macbook-pro-sd-card-issue/)
- [Notebookcheck: the new MacBook Pro's SD card reader reported dysfunctional in some units](https://www.notebookcheck.net/The-new-MacBook-Pro-s-SD-card-reader-is-reported-as-dysfunctional-in-some-units.579957.0.html)
- [Macworld: Apple reportedly working on a fix for the MacBook Pro SD card bug](https://www.macworld.com/article/558125/macbook-pro-sd-card-reader-issues-fix.html)
- [9to5Mac: 2021 MacBook Pro users reporting multiple issues with the SD card reader](https://9to5mac.com/2021/12/06/2021-macbook-pro-users-reporting-multiple-issues-with-the-sd-card-reader/)
- [Tom's Guide: MacBook Pro 2021 models reportedly hit by SD card reader problems](https://www.tomsguide.com/news/macbook-pro-2021-models-reportedly-hit-by-sd-card-reader-problems)
- [XDA-Developers: MacBook Pro 2021 SD card reader issues](https://www.xda-developers.com/macbook-pro-2021-sd-card-reader-issues/)
