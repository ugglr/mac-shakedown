# Calibration: Intel / T2 era (2016-2020)

Worked example covering the Intel-era Macs spanning the butterfly-keyboard, flexgate, and T2 years: MacBook Pro 13"/15"/16" (2016-2019), MacBook Air (2018-2019), MacBook 12" (2015-2017), Mac mini (2018), iMac Pro (2017), and Mac Pro (2019). This is one of the most defect-heavy Mac generations Apple shipped, and several of the defects were formally acknowledged via service or recall programs. Defects cluster where the data says: on pre-2019 laptops the dominant risks are the butterfly keyboard and the flexgate display-cable failure; on 2018+ T2 units the firmware, SSD, and power-management items matter more. The 16" 2019 is the generation's redemption unit (redesigned cooling, scissor keyboard) and is comparatively clean. Note that all three formal Apple programs (keyboard, flexgate, SSD) have now ended, so on a 2026 used purchase these are out-of-pocket repairs, which raises the practical severity of buying an affected unit.

This folder is **the reference material for failure analysis**. When `./run` produces a WARN or FAIL on a Mac whose target preset points here, read `Intel Quality Issues.md` and the relevant per-issue note to interpret the finding against documented batch defects.

## What's documented here

- **[Intel Quality Issues](Intel%20Quality%20Issues.md)**: overview / map of content for this generation
- **Issues/**: one note per confirmed or anecdotal defect:
	- [Butterfly Keyboard](Issues/Butterfly%20Keyboard.md): *the headline reliability defect, sticky / repeating / dead keys, 2016-2019*
	- [Flexgate Display Backlight](Issues/Flexgate%20Display%20Backlight.md): backlight cable fatigue, "stage light" effect, 2016-2018
	- [T2 Kernel Panics](Issues/T2%20Kernel%20Panics.md): bridgeOS sleep/wake panics on T2 units
	- [T2 USB Audio Glitch](Issues/T2%20USB%20Audio%20Glitch.md): pro-audio crackle / dropouts over USB 2.0
	- [13in SSD Data Loss](Issues/13in%20SSD%20Data%20Loss.md): non-Touch-Bar 2017-2018 SSD failure program
	- [2018 i9 Thermal Throttling](Issues/2018%20i9%20Thermal%20Throttling.md): firmware bug, fixed by supplemental update
	- [2015 15in Battery Recall](Issues/2015%2015in%20Battery%20Recall.md): *pre-scope fire-hazard recall, carried as context*
	- [2019 13in Unexpected Shutdowns](Issues/2019%2013in%20Unexpected%20Shutdowns.md): Apple-acknowledged two-port shutdowns
	- [2016 Radeon GPU Artifacts](Issues/2016%20Radeon%20GPU%20Artifacts.md): discrete GPU glitches on 15" 2016-2017
	- [Staingate Coating Delamination](Issues/Staingate%20Coating%20Delamination.md): *mostly pre-scope, historical context*
- **[Sources](Sources.md)**: references for everything in this folder

## How to use this folder

When a target preset has `"calibration_dir": "examples/intel-2016"`, this folder is the documented defect landscape for that generation. After `./run` finishes, if any phase produced WARN or FAIL, open `Intel Quality Issues.md` and cross-reference against the relevant per-issue note in `Issues/` to decide whether the signal matches a known defect class. Several of the worst defects here (keyboard, flexgate) are physical and not detectable by any automated phase, so the manual checklist (Phases 6 and 7) is load-bearing on pre-2019 units.

## Variant scope

| Variant | Most-relevant issues | Calibration applies? |
|---|---|---|
| MacBook 12" (2015-2017) | Butterfly keyboard | Yes (keyboard focus) |
| MacBook Pro 13"/15" (2016-2018) | Butterfly keyboard, flexgate, GPU artifacts (15") | Yes, primary focus |
| MacBook Pro 13"/15" non-TB SSD SKU (2017-2018) | 13" SSD data-loss program, butterfly keyboard | Yes |
| MacBook Pro 15" 2018 (i9) | i9 thermal throttling, T2 panics/audio, butterfly | Yes |
| MacBook Pro 13" 2019 two-port | Unexpected shutdowns, T2 items, butterfly | Yes |
| MacBook Air / Mac mini / iMac Pro (2017-2018, T2) | T2 panics, T2 USB audio glitch | Yes (T2 focus) |
| MacBook Pro 16" 2019 | Redemption unit, comparatively clean (see overview) | Context only |
| Retina 15" Mid-2015, 2012-2015 Retina | Battery recall, Staingate | Pre-scope context only |
