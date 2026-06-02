---
created: 2026-06-02
tags: [issue, anecdotal, display]
severity: low
detectable-on-site: manual-inspection
---

# MacBook Air M2 Uneven Bottom-Edge Backlight Bleed ("stage light")

Anecdotal: real, multi-user forum reports of uneven brightness along the bottom edge of the M2 Air panel, but the community is split on whether it exceeds normal IPS edge bleed. Not an Apple-acknowledged defect.

## Symptoms

- Uneven brightness, light blooms, or faint reddish-warm patches along the bottom edge (sometimes called "stage light" or "footlights").
- Most visible at high brightness on dark content; often fades at lower brightness.
- Disputed whether it exceeds normal IPS edge bleed.

## Suspected cause

- Edge-lit LED backlight non-uniformity near the bottom bezel where the backlight feeds in. On most units this is within normal IPS bleed variance rather than a hard defect.
- Terminology note: the classic "stage light" failure mode is a display-flex-cable wear issue (Flexgate) on 2016-2018 Intel MacBook Pros. On the M2 Air the term is used loosely for backlight non-uniformity, not the cable defect. There is no Apple repair program for M2 Air backlight bleed.

## Affected scope

- MacBook Air 13" M2 (2022), with some similar reports on the 15" M2 Air.
- LCD/IPS panels only.

## How to detect on-site

**Manual Phase 6 (display visual inspection).** The dark-screen uniformity check surfaces it.

- Display a full-black or dark image at max brightness in a dark room and inspect the bottom edge for blooms or color casts.
- Compare top vs bottom uniformity.
- Distinguish mild edge bleed (normal) from a concentrated bright column or a clear warm band (worth a replacement request while in warranty).

**Calibration note:** treat mild, symmetric bottom-edge bleed as normal IPS behavior and do not fail it. Flag only pronounced, localized non-uniformity.

## Sources

- [MacRumors forums: M2 MBA backlight bleed, how does your monitor look](https://forums.macrumors.com/threads/m2-mba-backlight-bleed-issue-how-does-your-monitor-look.2352944/)
- [Apple Discussions: M2 Air bottom-corner white bleed](https://discussions.apple.com/thread/255375811)
- [Apple Discussions: My M2 MBA has an unacceptable amount of backlight bleed](https://discussions.apple.com/thread/254073834)
- [AppleHeadlines: stage light MacBook explained (Flexgate vs backlight)](https://www.appleheadlines.com/stage-light-macbook/)
- [iFixit: Flexgate (the original "stage light" flex-cable defect)](https://www.ifixit.com/News/12903/flexgate)
- [MacRumors guide: Flexgate MacBook Pro display issue](https://www.macrumors.com/guide/flexgate-macbook-pro-display-issue/)
- [Apple Discussions: additional M2 Air backlight-bleed thread](https://discussions.apple.com/thread/256024503)
