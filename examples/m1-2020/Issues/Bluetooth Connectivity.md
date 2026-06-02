---
created: 2026-06-02
tags: [issue, bluetooth, big-sur, connectivity]
severity: low
detectable-on-site: manual-inspection
---

# Bluetooth Connectivity Issues (Disconnects / Mouse Stutter)

Bluetooth mice and keyboards stuttering, lagging, or disconnecting on early M1 Macs running macOS Big Sur 11.0.1. Confirmed across multiple outlets and Apple-acknowledged, but a transient launch-window software bug, largely resolved within months.

## Symptoms

- Bluetooth mice/keyboards stutter, lag, or randomly disconnect.
- Reported with Magic Mouse 2, Magic Keyboard/Trackpad, and Logitech MX Master (rapid connect/disconnect, jerky cursor).
- Mac mini M1 notably affected at launch.

## Suspected cause

A macOS Big Sur software/firmware bug, plus 2.4GHz coexistence interference (Apple pointed at the RF environment and Wi-Fi noise). Apple acknowledged the bug in January 2021 and shipped fixes in macOS Big Sur 11.2. This is mostly a software issue, not a per-unit hardware defect, though a crowded RF environment plus USB-3 interference can aggravate it. A residual minority reported lingering issues after 11.2, but that does not change the picture: low severity, software-resolved.

## Affected scope

Early M1 Macs (MacBook Air M1, Mac mini M1, MacBook Pro 13" M1) on macOS Big Sur 11.0.1. Largely resolved by subsequent Big Sur updates (11.2). In-thread commenters note Bluetooth flakiness is a long-standing macOS issue, not strictly Apple-Silicon-specific.

## How to detect on-site

Maps to **manual Phase 7 (functional inspection)**; **Phase 3 (sensor/port inventory)** confirms the Bluetooth controller is present. There is no automated stutter detection. Pair a Bluetooth mouse or keyboard and use it for a few minutes, watching for stutter or dropouts; test with Wi-Fi on and a USB-3 device attached to provoke interference. On a current macOS the issue should be gone, so persistent dropouts on a modern OS would warrant a closer look at the wireless module.

## Sources

- [MacRumors Forums: some Apple M1 Mac owners reporting Bluetooth connectivity issues (thread 2271512)](https://forums.macrumors.com/threads/some-apple-m1-mac-owners-reporting-bluetooth-connectivity-issues.2271512/)
- [AppleInsider: Apple plans macOS software fix for M1 Mac Bluetooth issues](https://appleinsider.com/articles/21/01/11/apple-plans-macos-software-fix-for-m1-mac-bluetooth-connectivity-issues)
- [AppleInsider: macOS Big Sur 11.2 now available with Bluetooth fixes for M1 Macs](https://appleinsider.com/articles/21/02/01/macos-big-sur-112-now-available-with-bluetooth-fixes-for-m1-macs)
- [TechRadar: M1 Macs finally get Bluetooth fix with macOS Big Sur 11.2](https://www.techradar.com/news/apple-macs-with-m1-chip-finally-get-bluetooth-fix-with-macos-big-sur-112)
- [Cult of Mac: macOS Big Sur 11.2 release, Mac Bluetooth fix](https://www.cultofmac.com/news/macos-big-sur-11-2-release-mac-bluetooth-fix)
- [Apple Community: 4th Gen 2020 M1 Mac mini Bluetooth issues (thread 252078550)](https://discussions.apple.com/thread/252078550)
