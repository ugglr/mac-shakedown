---
created: 2026-06-02
tags: [issue, gpu, display]
severity: medium
detectable-on-site: manual-inspection
---

# 2016-2017 MacBook Pro Discrete Radeon Pro GPU Artifacts

Screen artifacts and glitches on the 15" 2016-2017 discrete AMD GPU. The launch-window glitches were a confirmed software-driver bug; a smaller, anecdotal tail of hardware failures lingers.

## Symptoms

- Screen artifacts, colored lines, tearing, flashing or glitches (often on wake from sleep or under graphics load, notably with Adobe Premiere / Metal).
- In some long-term cases, black screen or crashes attributed to GPU failure.

## Suspected cause

Mixed. The 2016 launch-window glitches were largely attributed to a macOS graphics-driver bug, which Craig Federighi (via a widely-reported customer email) said was addressed in macOS 10.12.2. That the symptoms spanned multiple GPU types (Radeon Pro 460/450/455 and Intel Iris) supports a software root cause. A separate, longer-tail set of reports points to genuine discrete-GPU hardware degradation, exacerbated by the thin chassis' limited cooling, but that tail rests on forum/blog reports only and is anecdotal. There is no formal Apple GPU repair program for these models (the well-known Apple GPU program was for the 2011 MacBook Pro, a different generation).

## Affected scope

MacBook Pro 15" 2016-2017 with a discrete AMD Radeon Pro 4xx/5xx (450/455/460, 555/560). The software-glitch portion is confirmed by multiple outlets; the hardware-failure tail is anecdotal.

## How to detect on-site

This maps to **manual Phase 6 (display / external-monitor visual inspection) and manual Phase 7 (wake-from-sleep, external display)**. Drive the discrete GPU (force-enable it, play a GPU-heavy video or animation, connect an external display, wake repeatedly from sleep) while watching for artifacts, lines, or flashing. Run the Phase 6 solid-color screens on the internal panel to separate GPU artifacts from panel defects. Phase 5 thermal can stress the chassis but does not specifically exercise the dGPU artifact path, so this is largely a manual check. Ensure macOS is current, since the launch-window glitches were fixed in 10.12.2.

## Sources

- [9to5Mac: Federighi email, 2016 MBP graphics issues addressed in macOS 10.12.2](https://9to5mac.com/2016/12/07/apple-believes-2016-macbook-pro-graphics-issues-are-addressed-in-macos-10-12-2-update-according-to-craig-federighi-email/)
- [AppleInsider: 2016 MacBook Pro graphics issues likely caused by third-party software](https://appleinsider.com/articles/16/12/02/reported-2016-macbook-pro-graphics-issues-likely-caused-by-third-party-software)
- [MacRumors forums: GPU issue on new 2016 MacBook Pro (anecdotal corroboration)](https://forums.macrumors.com/threads/gpu-issue-on-new-2016-macbook-pro.2018272/)
- [AppleInsider: Apple email suggests GPU issues fixed in new Sierra version](https://appleinsider.com/articles/16/12/07/apple-email-response-suggests-that-gpu-issues-on-2016-retina-macbook-pro-fixed-in-new-sierra-version)
- [MacRumors: MacBook Pro graphics issues email](https://www.macrumors.com/2016/12/07/macbook-pro-graphics-issues-email/)
- [Apple: MacBook Pro video issues repair program (2011 models only, not 2016-2017)](https://www.apple.com/support/macbookpro-videoissues/)
