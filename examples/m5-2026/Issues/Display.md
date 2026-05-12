---
created: 2026-04-29
tags: [issue, display]
severity: low
detectable-on-site: yes
---

# Display Issues

The 14" / 16" mini-LED panels on M5 MBPs are praised overall. Reported issues are mostly *isolated unit defects* rather than a model-level problem. There is one design behavior that's **not a defect** to be aware of.

## Defects to test for

### Dead / stuck pixels
- **Dead pixel:** stays black on any background.
- **Stuck pixel:** stays one color (R, G, or B) on any background.
- Test: cycle full-screen pure colors (white, black, red, green, blue) and inspect closely.

### Backlight bleed
- Light leaking from edges / corners on a pure black background.
- Test: dim ambient light, set brightness ~30–50%, display full-screen black, look at edges and corners.
- Distinguish from **IPS glow** (shifts when you move your head; that's normal). Bleed stays put when you move.

### Backlight uniformity
- Display full-screen 50% gray and look for noticeably brighter / darker patches.
- Healthy mini-LED panels show some banding from local dimming zones (that's normal). Severe patches are not.

### Color uniformity / tint
- Full-screen white. Look for yellow / pink / blue patches, especially toward the edges.

## Design behaviors that are NOT defects (don't reject for these)

- **Mini-LED blooming:** subtle glow around bright objects on dark backgrounds. Each backlight zone covers many pixels, so you can't get perfect contrast at bright/dark boundaries. Inherent to mini-LED, not a defect.

## How to test on-site

There are several free web-based pixel testers. Load them full-screen in Safari:
- `deadpixeltest.org`
- `touch-screen-test.com/screen-test`
- `black-screen.cc/black-screen-test`

For the verification script, we can launch a sequence of full-screen color images locally (no internet needed in store).

## Sources

- [Apple Discussions: display issue hardware or software](https://discussions.apple.com/thread/256214402)
- [Dead Pixel Test online tool](https://deadpixeltest.org/)
- [ShopSavvy: M5 display specs](https://shopsavvy.com/answers/macbook-pro-m5-display-screen-quality-specifications)
