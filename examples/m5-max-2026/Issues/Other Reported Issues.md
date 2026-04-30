---
created: 2026-04-29
tags: [issue, misc]
severity: low
detectable-on-site: yes
---

# Other Reported Issues

Catch-all for less common but worth-checking unit-level defects.

## Speaker crackling / distortion

- Reported on prior MBP generations; isolated reports on M5.
- Test: play full-range audio at 70%+ volume, listen for crackle, buzz, asymmetry between left and right.
- Use a sweep tone (20 Hz → 20 kHz) to expose buzzing.

## Microphone

- Some user reports of FaceTime mic failures (often software-side, but worth confirming).
- Test: QuickTime → New Audio Recording → speak → check level meter and playback.
- All three mic capsules should pick up — try shifting voice direction.

## Camera (12 MP Center Stage)

- No widespread M5-specific issues, but always worth a smoke test.
- Test: Photo Booth → check live feed, capture a still, check for banding / dead pixels in the sensor.

## Wi-Fi activation issues

- Some users couldn't complete initial setup over Wi-Fi.
- Test: connect to Wi-Fi during first-boot setup. If it fails, that's a red flag — could indicate radio module problem.

## Ports (Thunderbolt 5 / USB-C)

- Test each port individually:
	1. Power delivery — plug charger into each port, confirm charging.
	2. Data — plug a USB-C drive or Thunderbolt device, confirm mounts and reads.
	3. Display out — plug an external display if available.
- A port that charges but doesn't pass data (or vice versa) indicates a damaged controller.

## MagSafe

- Plug and unplug a few times. LED should change color (amber → green) as it charges.
- Magnet should hold firmly but disengage cleanly.

## SD card slot (16" only)

- Test with any SD card if you have one — read and write.

## Trackpad

- Force Touch should click uniformly across the entire surface — corners, edges, center.
- No mechanical click sound (it's a haptic engine; clicks are simulated).
- Multitouch gestures (two-finger scroll, three-finger swipe) work smoothly.

## Keyboard

- Test every key — best done with a key tester website or by typing the alphabet, numbers, and modifier combos.
- Look for sticky, double-press, or non-responsive keys.
- Backlight uniform across all keys.
- Touch ID enrollment works (functional sensor).

## Sources

- General checklist: [MacRumors — Ultimate new MacBook checklist](https://forums.macrumors.com/threads/the-ultimate-new-macbook-checklist-what-to-test-when-you-get-a-freshie.2129147/)
- Apple Diagnostics: [Apple Support](https://support.apple.com/en-us/102550)
