---
created: 2026-06-02
tags: [research, sources]
---

# Sources

All references for the M4 generation (2024-2025) calibration, grouped by issue.

## M4 JIT Kernel Panic (SPTM)

- [Ruby tracker #20890: MacOS 15.1, MacBook Pro 2024 M4, YJIT kernel panic](https://bugs.ruby-lang.org/issues/20890). Exact SPTM VIOLATION_ILLEGAL_SPRR_INDEX panic, M4-only (M1/M2 unaffected), Apple-fixed in 15.2.
- [Puma #3551: Kernel Panic on M4 chips](https://github.com/puma/puma/issues/3551). Same SPTM fault on M4 Max, attributed to macOS, reported to Apple, labeled invalid (OS-level).
- [Hacker News #42174838: Apple M4 Kernel Panic Ruby/PHP JIT](https://news.ycombinator.com/item?id=42174838). Links to the Ruby tracker.
- [JetBrains YouTrack JBR-7968](https://youtrack.jetbrains.com/issue/JBR-7968). Identical panic string (sptm_map_page sptm.c:406) on M4 with JetBrains IDEs.
- [OpenZFS on OSX forum](https://openzfsonosx.org/forum/viewtopic.php?f=26&t=3915). M4 instability and SPTM kernel panics discussion.

## Mac mini Wi-Fi Near Docks

- [AppleInsider: How to fix weak Wi-Fi on an M4 Mac mini connected to a drive or dock](https://appleinsider.com/inside/mac-mini/tips/how-to-fix-weak-wi-fi-on-a-m4-mac-mini-when-connected-to-a-drive-or-dock). Canonical primary reporting on antenna-under-plastic-base plus metal dock attenuation.
- [Michael Tsai: Weak M4 Mac mini Wi-Fi](https://mjtsai.com/blog/2025/03/10/weak-m4-mac-mini-wi-fi/). Aggregates the AppleInsider report and reader workarounds.
- [Apple Discussions: Mac mini M4 Wi-Fi unresponsive](https://discussions.apple.com/thread/255860420). Degraded by connected drives/USB, bottom-cover antenna placement.
- [Hacker News #43332832](https://news.ycombinator.com/item?id=43332832). Independent discussion of the same AppleInsider article.
- [MacRumors: new M4 mini Wi-Fi video thread](https://forums.macrumors.com/threads/if-you-have-a-new-mac-m4-mini-you-need-to-watch-this-video.2446672/). Independent forum corroboration.
- [Jason Deegan: docks block Wi-Fi signals on the Mac mini M4](https://jasondeegan.com/beware-some-docks-block-wifi-signals-on-the-mac-mini-m4/). Independent blog confirmation.

## Thunderbolt 5 Portable Monitor Power

- [Apple Discussions: MacBook Pro M4 with Thunderbolt 5 and portable monitor](https://discussions.apple.com/thread/255844359). Primary thread (posted Nov 14 2024); 3 portable monitors fail on single-cable power+signal on M4 Pro TB5.
- [MacRumors: Mac mini M4 Pro can't power portable displays via TB5](https://forums.macrumors.com/threads/mac-mini-m4-pro-cant-power-portable-displays-via-tb5.2449467/). Zeuslap P16UK/P16K PD30W monitors work via single TB4 cable but require external power on TB5.
- [Apple Discussions: USB-C portable (Arzopa) monitor not working on M4 TB5](https://discussions.apple.com/thread/255905568). Additional on-topic thread.
- [Macworld: Thunderbolt version comparison 5 / 4 / 3 vs USB4](https://www.macworld.com/article/675887/feature-thunderbolt-version-comparison-5-4-3-vs-usb4.html). TB5 allows up to 240W charging, contradicting the "TB5 provides lower bus power by spec" cause.
