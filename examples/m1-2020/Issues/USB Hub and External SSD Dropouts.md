---
created: 2026-06-02
tags: [issue, usb, storage, monterey]
severity: medium
detectable-on-site: partial
---

# USB Hub / External SSD Disconnects and Dropouts (Monterey)

External drives behind USB and Thunderbolt hubs randomly ejecting, and USB hubs failing to enumerate downstream devices, on M1 Macs running macOS Monterey. Confirmed across multiple outlets. Data-loss-adjacent during long transfers, but workaround-able and partly hardware-dependent.

## Symptoms

- External drives behind USB/Thunderbolt hubs randomly eject or disconnect mid-use, for example during video renders.
- Drives spontaneously remount; hubs fail to enumerate downstream devices.
- Hubs that worked reliably in the Intel era suddenly unreliable.

## Suspected cause

This entry covers two distinct but overlapping things. (1) A genuine Monterey-specific USB-hub port-enumeration regression: USB 3.0 ports go dead and downstream devices fail to enumerate, which appeared in betas and persisted into 12.0.1. (2) External-SSD disconnect-on-sleep behavior, which is also reported on Big Sur on M1, so the clean "worked on Big Sur, broke on Monterey" narrative is only partly true for the SSD-sleep symptom. Part of the SSD/HDD disconnect behavior is design behavior, not pure defect: Apple Silicon reduces USB bus power in standby, and bus-powered drives on unpowered hubs can drop. The widely-cited mitigations follow from that: disable "put hard drives to sleep", use a powered/quality hub (for example CalDigit), swap cables/adapters, and update to 12.1+. Partial improvement is confirmed: 12.1 fixed it for many, but it persisted into 12.3.x for some.

## Affected scope

M1 / Apple Silicon Macs (notably Mac mini M1) on macOS Monterey. Many USB 3.x hubs and bus-powered external SSDs/HDDs affected.

## How to detect on-site

The practical catch is **manual Phase 7 (functional port test)**, and **Phase 3 (port inventory)** confirms ports enumerate. **Phase 11 (SSD sequential test)** is internal-only, but its methodology (sustained large read/write) is exactly what would expose a dropping external drive if pointed at one. Plug an external SSD (ideally through a hub) into each USB-C/Thunderbolt port, run a sustained read/write (large file copy) for several minutes per port, and watch for unexpected unmounts. Test each physical port to catch a single bad port.

## Sources

- [MacRumors: macOS Monterey USB hub issues reported](https://www.macrumors.com/2021/10/29/monterey-usb-hub-issues-reported/)
- [MacRumors Forums: Monterey users report connectivity issues with USB hubs (thread 2320450)](https://forums.macrumors.com/threads/macos-monterey-users-report-connectivity-issues-with-usb-hubs.2320450/)
- [Apple Developer Forums: USB hub failing under Monterey, M1 MacBook Air (thread 683409)](https://developer.apple.com/forums/thread/683409)
- [Apple Community: External SSD disconnects repeatedly, Mac mini M1 Big Sur (thread 252346675)](https://discussions.apple.com/thread/252346675)
- [Apple Community: USB 3 hub disconnecting randomly, 2021 MBP M1 Pro (thread 253608747)](https://discussions.apple.com/thread/253608747)
- [AppleToolBox: macOS Monterey breaks USB hubs](https://appletoolbox.com/macos-monterey-breaks-usb-hubs/)
- [CleanMyMac: USB devices disconnecting on Monterey and mitigations](https://cleanmymac.com/blog/usb-devices-disconnecting-monterey)
- [MacRumors Forums: has the Monterey disconnection issue been fixed (thread 2357723)](https://forums.macrumors.com/threads/has-monterey-disconnection-issue-with-external-drives-been-fixed.2357723/)
