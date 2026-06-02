---
created: 2026-06-02
tags: [issue, display, m1-imac, high-voltage-cable]
severity: high
detectable-on-site: manual-inspection
---

# 24" M1 iMac Display Lines / Flickering

The standout hardware defect of the generation: permanent display degradation on the 24" M1 iMac (2021), appearing as horizontal lines, banding, and flicker, clustering just past the one-year warranty.

## Symptoms

- Faint gray or black lines along the bottom of the screen that grow into solid horizontal or vertical bands.
- Flickering, and sometimes sections of the screen blacking out.
- Correlated with higher brightness and heat: brighter use brings it on sooner.

## Suspected cause

A repair technician's investigation (originally surfaced via Tom's Hardware, then re-reported by every outlet) points to degradation of a high-voltage (~50V) flex cable / FFC that powers the LCD at the top of the panel. Over time the connector degrades and signals leak or short, producing lines, and heat accelerates it. The consistent worldwide pattern and predictable 18-24 month timeline suggest a systematic component or design quality issue rather than random failure. Treat the precise ~50V mechanism as a widely-reported technician hypothesis (plausible), not established fact: Apple has not confirmed a mechanism and there is no teardown or lab verification. The fix in practice is a full display-assembly replacement, roughly $600-700 out of warranty. There is no Apple repair program as of mid-2026. Reports of similar symptoms on later iMac revisions exist but are thinner, so treat that spillover as lower-confidence.

## Affected scope

24" M1 iMac (2021). Reports cluster around the 18-24 month / just-out-of-warranty mark, across both fan configurations, and span multiple regions (HK, SG, IN, ID, MY, TW, EU, US).

## How to detect on-site

Maps to **Phase 6 (display visual inspection)**, where solid-field color tests are exactly the catch. Run full-screen solid color fields (white, gray, black, R/G/B) at high brightness and watch for horizontal or vertical lines, banding, or flicker, especially near the bottom edge. Run for several minutes at max brightness, since heat triggers it. This is a known-risk note as much as a live check: on a fresh-ish unit the defect may not yet manifest, so a clean display today does not rule out future onset. No automated phase surfaces this.

## Sources

- [iFixit: Horizontal lines over iMac 24 screen (Answers #805617)](https://www.ifixit.com/Answers/View/805617/Horizontal+lines+over+iMac+24+screen)
- [Tom's Hardware: Apple Silicon iMacs suffer screen deterioration after two years](https://www.tomshardware.com/software/macos/apple-silicon-imacs-appear-to-suffer-from-screen-deterioration-after-two-years-flood-of-user-complaints-hit-apple-community-forums)
- [AppleInsider: M1 iMacs failing with dark horizontal lines](https://appleinsider.com/articles/24/10/07/m1-imacs-failing-with-dark-horizontal-lines-on-screen)
- [TechRadar: M1 iMac users complain of screen fault, seek recall or free repair](https://www.techradar.com/computing/macs/recall-or-free-repair-apple-m1-imac-users-complain-of-screen-fault-but-claim-apple-is-refusing-to-take-responsibility)
- [TechSpot: iMac M1 users report permanent display problem](https://www.techspot.com/news/105030-apple-imac-m1-users-report-permanent-display-problem.html)
- [Apple Community: M1 iMac screen flickering, a persistent issue (thread 255994372)](https://discussions.apple.com/thread/255994372)
- [MacRumors Forums: iMac (M1, 2021) display issue (thread 2423630)](https://forums.macrumors.com/threads/imac-m1-2021-display-issue.2423630/)
- [iPhone in Canada: M1 iMac display lines and the bad cable theory](https://www.iphoneincanada.ca/2024/10/07/m1-imac-display-lines-bad-cable/)
