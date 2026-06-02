# Calibration: M3 generation (2023-2024)

Worked example covering the 2023-2024 Apple Silicon M3 generation: `Apple M3`, `M3 Pro`, and `M3 Max` across the MacBook Pro 14"/16" (Nov 2023), iMac 24" (Nov 2023), and MacBook Air 13"/15" (Mar 2024). By Apple Silicon standards this is a relatively clean generation for genuine batch-level defects: there is no Apple recall or service program for any M3 Mac as of mid-2026. Defects cluster where the data says, which is mostly the iMac 24" display assembly (the inherited flex-cable failure), plus a handful of low-severity, largely usage- or software-driven annoyances on the notebooks. Most of the loud M3 narratives (8GB base RAM, M3 Pro memory bandwidth, space-black fingerprints, 14" M3 Max throttling) are spec, pricing, or design-behavior debates, not failures.

This folder is **the reference material for failure analysis**. When `./run` produces a WARN or FAIL on a Mac whose target preset points here, read `M3 Quality Issues.md` and the relevant per-issue note to interpret the finding against documented batch defects.

## What's documented here

- **[M3 Quality Issues](M3%20Quality%20Issues.md)**: overview / map of content for this generation, including the design-behavior items that are deliberately NOT given their own issue files
- **Issues/**: one note per confirmed or anecdotal defect:
	- [iMac Display Flex-Cable Failure](Issues/iMac%20Display%20Flex-Cable%20Failure.md): *the one genuine high-severity hardware-defect class, but latent and inherited from the M1 iMac*
	- [Keyboard Marks on Display](Issues/Keyboard%20Marks%20on%20Display.md): cosmetic, confirmed across multiple outlets, a general thin-lid MacBook trait
	- [Display Flicker](Issues/Display%20Flicker.md): internal ProMotion and external-monitor flicker, mostly software-first triage
	- [Wi-Fi and Bluetooth Complaints](Issues/Wi-Fi%20and%20Bluetooth%20Complaints.md): scattered, environment/firmware dependent, no batch-defect pattern
- **[Sources](Sources.md)**: references for everything in this folder

## How to use this folder

When a target preset has `"calibration_dir": "examples/m3-2023"`, this folder is the documented defect landscape for that generation. After `./run` finishes, if any phase produced WARN or FAIL, open `M3 Quality Issues.md` and cross-reference the relevant per-issue note in `Issues/` to decide whether the signal matches a known defect class or is expected design behavior. Because the headline M3 defect (the iMac flex cable) is latent and time-driven, a clean on-site inspection does not rule it out on an older used iMac.

## Variant scope

| Variant | Most-relevant issues | Calibration applies? |
|---|---|---|
| iMac 24" M3 | **Display flex-cable failure** (latent, ~2yr onset), display flicker | Yes, primary defect focus |
| M3 (Air 13"/15", base MBP 14") | Keyboard marks, Wi-Fi/BT, 8GB base-RAM context | Yes |
| M3 Pro (MBP 14"/16") | Keyboard marks, display flicker, Wi-Fi/BT, 150 GB/s bandwidth context | Yes |
| M3 Max (MBP 14"/16") | Keyboard marks, display flicker, 14" thermal-throttling design context | Yes |
