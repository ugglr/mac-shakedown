---
created: 2026-06-02
tags: [issue, wifi, big-sur, connectivity]
severity: low
detectable-on-site: manual-inspection
---

# Wi-Fi Dropping / Slow After Wake (Big Sur)

Frequent Wi-Fi drops and slow throughput, especially after wake from sleep, on M1 Macs running macOS Big Sur. Broadly documented and predominantly software, resolved by updates and config changes.

## Symptoms

- Frequent Wi-Fi drops and failure to reconnect reliably.
- Slow throughput, especially after wake from sleep, sometimes needing to forget/rejoin the network or reboot.

## Suspected cause

macOS Big Sur networking and sleep-wake bugs, aggravated by VPN clients (notably Cisco AnyConnect, whose packet filter was a documented root cause) and by RF interference from attached USB devices/hubs. The most prominent systemic root cause in tier-1 reporting is the AWDL interface (AirDrop/AirPlay), fixed in macOS 13.1. This is generally software, not a hardware antenna defect, with isolated hardware-repair outliers rather than a systemic defect, hence low severity.

## Affected scope

M1 Macs on macOS Big Sur, with some M1 Pro reports. Predominantly software, resolved by updates and config changes.

## How to detect on-site

Maps to **manual Phase 7 (functional / network check)**; **Phase 3 (inventory)** confirms the Wi-Fi interface is present. Not automated as pass/fail. Connect to Wi-Fi, run a speed test, sleep and wake the machine and re-test, and check for drops over several minutes. Persistent failure on a current macOS (well past Big Sur) would be more suspicious of hardware than the original software-era reports.

## Sources

- [Apple Community: MacBook M1 Pro keeps dropping Wi-Fi randomly (thread 253452348)](https://discussions.apple.com/thread/253452348)
- [Apple Developer Forums: Big Sur, Wi-Fi dropping constantly (thread 653001)](https://developer.apple.com/forums/thread/653001)
- [OSXDaily: how to fix macOS Big Sur Wi-Fi issues](https://osxdaily.com/2020/11/23/how-fix-macos-big-sur-wifi-issues/)
- [9to5Mac: M1/M2 Wi-Fi issues are a software (AWDL) issue, fixed in macOS 13.1](https://9to5mac.com/2022/12/12/macbook-wifi-issues-m1-m2-fix/)
- [Apple Developer Forums: problems with Wi-Fi on macOS Big Sur (thread 650133)](https://developer.apple.com/forums/thread/650133)
- [macReports: Wi-Fi not working after Big Sur upgrade](https://macreports.com/wi-fi-not-working-after-big-sur-upgrade/)
