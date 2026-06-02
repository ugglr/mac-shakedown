---
created: 2026-06-02
tags: [issue, thunderbolt-5, displays, peripherals, anecdotal]
severity: low
detectable-on-site: manual-inspection
---

# Thunderbolt 5 Portable Monitor Power

Bus-powered single-cable USB-C portable monitors that work on TB4 Macs fail to power on or are not detected on M4 Pro / M4 Max Thunderbolt 5 ports. Symptom is corroborated across several first-hand reports, but it is community-sourced and the root cause is unverified.

## Symptoms

- A bus-powered single-cable USB-C portable monitor (for example Zeuslap or Arzopa panels around 30W PD) that powers and displays fine on a TB4 Mac fails to power on, or is not detected, on a TB5 port.
- Same symptom reported on Mac mini M4 Pro, not just the MacBook Pro.
- Workarounds reported: external power to the monitor, an intermediate USB-C hub, HDMI plus separate power, or a monitor firmware / macOS update.

## Suspected cause

The leading user hypothesis is that TB5 ports provide lower bus power (one report cites roughly 4.5W outbound), but this is unverified. The TB5 spec actually allows up to 240W charging, so this is not a spec-level power limit. The true cause is more likely a USB-C PD / DisplayPort Alt Mode negotiation bug. Reports that a firmware or macOS update fixed it for some users point to a software/firmware compatibility issue rather than a fixed hardware design limit. Treat the specific "15W minimum" and "an update fixed it" details as unconfirmed.

## Affected scope

- MacBook Pro M4 Pro / M4 Max (2024), which have TB5 ports. The base M4 has TB4 and is not implicated.
- Mac mini M4 Pro (TB5) reproduced the same symptom.
- Niche peripheral class (bus-powered portable monitors), clear workarounds exist, and it appears partially resolvable via updates. Severity stays low.

## How to detect on-site

Manual inspection, tied to Phase 6 (ports / peripherals). Not a behavioral signal the harness measures. If you carry a bus-powered single-cable portable monitor, plug it into each TB5 port and confirm it powers and is detected on a single cable. If it only works with external power or through a hub, you have reproduced the issue. Because the cause is most likely a PD / Alt Mode negotiation bug that updates can address, confirm the monitor firmware and macOS are current before treating it as a hardware fault.

## Sources

- [Apple Discussions: MacBook Pro M4 with Thunderbolt 5 and portable monitor](https://discussions.apple.com/thread/255844359)
- [MacRumors: Mac mini M4 Pro can't power portable displays via TB5](https://forums.macrumors.com/threads/mac-mini-m4-pro-cant-power-portable-displays-via-tb5.2449467/)
- [Apple Discussions: USB-C portable (Arzopa) monitor not working on M4 TB5](https://discussions.apple.com/thread/255905568)
- [Macworld: Thunderbolt version comparison (TB5 allows up to 240W charging)](https://www.macworld.com/article/675887/feature-thunderbolt-version-comparison-5-4-3-vs-usb4.html)
