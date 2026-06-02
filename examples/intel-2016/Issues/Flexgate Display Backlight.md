---
created: 2026-06-02
tags: [issue, critical, display, flexgate]
severity: high
detectable-on-site: manual-inspection
---

# Flexgate Display Backlight Cable Failure

Progressive backlight failure caused by a too-short display flex cable that fatigues over the hinge. Starts as a "stage light" effect and ends with the backlight dying.

## Symptoms

- Uneven backlighting along the bottom of the screen (the "stage light" or "stage curtain" effect).
- Progresses to the backlight cutting out entirely once the lid is opened past roughly 40 degrees.
- The display may work only at small hinge angles before failing completely.

## Suspected cause

The display backlight flex cable was designed too short and routed over the hinge. Repeated opening and closing fatigues and eventually fractures the cable. Because the cable is integral to the display assembly on these models (not separately serviceable), repair historically meant a full display replacement.

## Affected scope

MacBook Pro 13"/15" 2016-2018 (some 2019 reported). Important scope correction: Apple's Display Backlight Service Program covered **only the 13" 2016** (both Two and Four Thunderbolt 3 Port variants). The 13" 2017 used the identical display assembly and showed the same failure but was never officially covered, and all 15" models were affected but never covered. The program has since ended, so on a 2026 purchase this is an out-of-pocket full-display repair on most affected units.

## How to detect on-site

This maps to **manual Phase 6 (display white/gray inspection) plus manual Phase 7 (hinge open/close)**, and is not detectable by automated phases. The defect is angle-dependent, so the inspector must specifically open the lid to full extension. Open and close the lid several times and watch the lower edge of the screen for uneven "stage light" banding. Then open the lid fully (past ~90 degrees) on a white or gray background and check for backlight dropout or flicker near the hinge. Combine with the Phase 6 white/gray screens.

## Sources

- [iFixit: MacBook Pro flexgate repair program](https://www.ifixit.com/News/16943/macbook-pro-flexgate-repair-program)
- [iFixit: Flexgate teardown (backlight fails past ~40 degrees)](https://www.ifixit.com/News/12903/flexgate)
- [MacRumors: Flexgate guide](https://www.macrumors.com/guide/flexgate/)
- [Apple: 13-inch MacBook Pro display backlight service (program ended)](https://support.apple.com/13-inch-macbook-pro-display-backlight-service)
- [9to5Mac: how to check MacBook Pro display repair eligibility](https://9to5mac.com/2019/05/21/check-macbook-pro-display-repair/)
- [AppleInsider: Apple sued over "stage light" display issue](https://appleinsider.com/articles/20/08/20/apple-sued-over-stage-light-macbook-pro-display-issue)
- [MacRumors: Jan 2021 extension of the 13" backlight program](https://www.macrumors.com/2021/01/17/apple-extends-13-macbook-pro-backlight-program/)
