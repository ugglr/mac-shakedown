# Calibration: M2 generation (2022-2023)

Worked example covering the 2022-2023 Apple Silicon M2 generation: `Apple M2`, `M2 Pro`, `M2 Max`, and `M2 Ultra` across MacBook Air 13"/15", MacBook Pro 13"/14"/16", Mac mini, and Mac Studio. The M2 was a mature, mostly clean refresh, so this generation has fewer batch defects than the headlines suggest. The one genuinely confirmed regression is in storage: base 256GB consumer SSDs and the 512GB M2 Pro tier shipped with fewer NAND dies and measurably lower sequential throughput than the M1 models they replaced. Everything else here is either anecdotal (thin-display cracking, bottom-edge backlight bleed, 13" M2 throttling) or expected design behavior rather than a defect. Defects cluster where the data says: storage, and the thin MacBook Air lid.

This folder is **the reference material for failure analysis**. When `./run` produces a WARN or FAIL on a Mac whose target preset points here, read `M2 Quality Issues.md` and the relevant per-issue note to interpret the finding against documented batch defects.

## What's documented here

- **[M2 Quality Issues](M2%20Quality%20Issues.md)**: overview / map of content for this generation
- **Issues/**: one note per confirmed or anecdotal defect:
	- [256GB SSD Speed Regression](Issues/256GB%20SSD%20Speed%20Regression.md): *the headline defect, single NAND die halves sequential speed on base 256GB configs*
	- [512GB M2 Pro SSD Regression](Issues/512GB%20M2%20Pro%20SSD%20Regression.md): *two dies instead of four on the 512GB M2 Pro tier*
	- [MacBook Air Display Cracking](Issues/MacBook%20Air%20Display%20Cracking.md): *anecdotal, thin-lid point-pressure cracking*
	- [Bottom-Edge Backlight Bleed](Issues/Bottom-Edge%20Backlight%20Bleed.md): *anecdotal, panel uniformity variance*
	- [13-inch M2 Thermal Throttling](Issues/13-inch%20M2%20Thermal%20Throttling.md): *single-source, single-fan chassis under extreme sustained load*
- **[Sources](Sources.md)**: references for everything in this folder

## How to use this folder

When a target preset has `"calibration_dir": "examples/m2-2022"`, this folder is the documented defect landscape for that generation. After `./run` finishes, if any phase produced WARN or FAIL, open `M2 Quality Issues.md` and cross-reference against the relevant per-issue note in `Issues/` to decide whether the signal matches a known defect class. For the SSD issues in particular, the right baseline depends on capacity, so check the storage tier before reading a slow result as a fault.

## Variant scope

| Variant | Most-relevant issues | Calibration applies? |
|---|---|---|
| M2 (Air 13"/15", MBP 13", Mac mini) | **256GB SSD regression**, Air display cracking, backlight bleed, 13" throttling | Yes, primary focus |
| M2 Pro (MBP 14"/16", Mac mini) | **512GB SSD regression** | Yes |
| M2 Max (MBP 14"/16", Mac Studio) | No documented M2-specific defects; uses multiple NAND dies | Context only |
| M2 Ultra (Mac Studio, Mac Pro) | No documented defects; brief manual acoustic check on Studio | Context only |
