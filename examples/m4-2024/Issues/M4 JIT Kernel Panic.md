---
created: 2026-06-02
tags: [issue, kernel-panic, jit, macos-15, fixed]
severity: medium
detectable-on-site: no
---

# M4 JIT Kernel Panic (SPTM)

Full system kernel panic and reboot when M4-family Macs run JIT-compiled workloads on macOS Sequoia 15.0-15.1. Apple-acknowledged and fixed in macOS 15.2.

## Symptoms

- Full system kernel panic / reboot, not a process crash.
- Panic string: `SPTM VIOLATION_ILLEGAL_SPRR_INDEX` (reported as `sptm_map_page sptm.c:406` in some traces).
- Triggered by JIT-compiled workloads: Ruby with YJIT enabled, PHP opcache, Puma, and JetBrains IDEs have all reproduced the same fault.
- M1 / M2 not affected. No explicit M3 negative test was found, but sources name only M1/M2 as tested-clean, so M3 is plausibly unaffected.

## Suspected cause

Apple-side silicon/OS bug in the SPTM (Secure Page Table Monitor) path on the M4 family. This is confirmed, not theory: Apple's macOS 15.2 release note states it "Resolved an issue where running Ruby with YJIT enabled causes Mac with M4 chip to kernel panic." Apple's public note names only Ruby/YJIT explicitly; the broader cross-JIT and PHP-opcache scope is multi-source but more anecdotal.

## Affected scope

- All M4-family SoCs: M4, M4 Pro, M4 Max.
- macOS Sequoia 15.0-15.1 only (Darwin 24.1.0).
- Fixed in macOS 15.2. No longer reproducible on 15.2 or later.
- Reproduced first-hand on M4 Max MacBook Pro and Mac mini M4 (PHP opcache).

## How to detect on-site

Not detectable by the harness, and not worth probing as a hardware fault. This is version-gated: check Phase 1 inventory for the macOS / Darwin version. If macOS is 15.2 or later, the issue is closed. The only residual relevance is calibration history for units still on 15.0-15.1, where the workaround is to update to 15.2 (or disable JIT). It is meaningful as a "what this generation went through," not a defect to actively trigger.

## Sources

- [Ruby tracker: MacOS 15.1, MacBook Pro 2024 M4, YJIT kernel panic](https://bugs.ruby-lang.org/issues/20890)
- [Puma: Kernel Panic on M4 chips](https://github.com/puma/puma/issues/3551)
- [Hacker News: Apple M4 Kernel Panic Ruby/PHP JIT](https://news.ycombinator.com/item?id=42174838)
- [JetBrains YouTrack JBR-7968: identical SPTM panic on M4 with IDEs](https://youtrack.jetbrains.com/issue/JBR-7968)
- [OpenZFS on OSX: M4 instability and SPTM kernel panics](https://openzfsonosx.org/forum/viewtopic.php?f=26&t=3915)
