---
created: 2026-06-02
tags: [research, overview]
---

# M4 Quality Issues: Overview

High-level summary of known issues with the 2024-2025 M4 / M4 Pro / M4 Max line, as of **2026-06-02**.

This was a clean generation. There is no headline batch defect on the order of the M5 Max performance variance. The most serious item is an Apple OS/silicon bug (JIT kernel panic) that Apple already fixed in macOS 15.2, so it matters mainly as version-gated history. The remaining items are low-severity peripheral interactions.

## Summary table

| Issue | Severity | Scope | Detectable on-site? |
|---|---|---|---|
| [M4 JIT kernel panic (SPTM)](Issues/M4%20JIT%20Kernel%20Panic.md) | Medium, fixed in macOS 15.2 | All M4-family SoCs on macOS 15.0-15.1 | No (OS-version-gated, not a hardware probe) |
| [Mac mini Wi-Fi near docks](Issues/Mac%20mini%20Wi-Fi%20Near%20Docks.md) | Low | Mac mini M4 / M4 Pro (2024) | Manual inspection only |
| [Thunderbolt 5 portable monitor power](Issues/Thunderbolt%205%20Portable%20Monitor%20Power.md) | Low | MacBook Pro M4 Pro / M4 Max, Mac mini M4 Pro (TB5 ports) | Manual inspection (Phase 6) |

## What's confirmed vs. anecdotal

**Confirmed by multiple outlets:**
- M4 JIT / SPTM kernel panic under JIT-compiled workloads (Ruby YJIT, PHP opcache, Puma) on macOS 15.0-15.1, Apple-acknowledged and fixed in 15.2 (Ruby tracker, Puma, Hacker News, plus JetBrains and OpenZFS corroboration).
- Mac mini M4 Wi-Fi throughput drop when the unit sits on or near a metal dock or external drive (AppleInsider, mjtsai, Apple Discussions, MacRumors, Hacker News).

**Community-sourced but credible (multiple first-hand reports, not officially confirmed):**
- Thunderbolt 5 ports failing to power bus-powered single-cable portable monitors that work fine on TB4. The symptom is corroborated across several first-hand reports (Apple Discussions, MacRumors), but it is community-sourced and not confirmed by Apple, press, or lab testing.

**Not a defect, but design behavior / context to expect:**
- The Mac mini Wi-Fi issue is RF physics, not a manufacturing fault: the antenna sits under the thin plastic base, and an adjacent metal enclosure (dock or drive) attenuates it. Off-brand or poorly shielded USB cables can cause the same symptom independent of any dock. Easily mitigated by repositioning the unit or using a better-shielded cable, which is why it stays at low severity.
- The TB5 portable-monitor suspected cause ("TB5 ports provide lower bus power") is an unverified user hypothesis. The TB5 spec actually allows up to 240W charging, so this is not a spec-level power limit. The true cause is more likely a USB-C PD / DisplayPort Alt Mode negotiation bug, and some users report a firmware/macOS update resolved it, which points to a software/firmware compatibility issue rather than a fixed hardware limitation.

## Implication for verification

For this generation the harness does most of its work as confirmation rather than detection. The JIT kernel panic is fully version-gated: if Phase 1 inventory reports macOS 15.2 or later, that issue is closed and not worth probing. The two peripheral issues are not behavioral signals the harness measures; they surface during manual handling (Phase 6 ports / peripherals, plus general inspection). When `./run` is clean on an M4, that is consistent with the data: this generation's real risks live in OS version and peripheral pairing, not silicon or build quality.
