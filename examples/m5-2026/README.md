# Calibration: M5 generation (2026)

Worked example covering the 2026 Apple Silicon M5 generation, `Apple M5`, `M5 Pro`, and `M5 Max` across MacBook Air, MacBook Pro 14"/16", Mac mini, Mac Studio, and iMac. Most of the documented batch defects so far cluster around the **M5 Max** specifically (notably the multi-core performance variance described in [Issues/Performance Variance.md](Issues/Performance%20Variance.md)), but the surrounding context (display / battery / build quality / repairability) applies to the whole generation.

This folder is **the reference material for failure analysis**. When `./run` produces a WARN or FAIL verdict on a Mac whose target preset points here, read `M5 Quality Issues.md` and the relevant per-issue note to interpret the finding against documented batch defects.

## What's documented here

- **[M5 Quality Issues](M5%20Quality%20Issues.md)**: overview / map of content for this generation
- **Issues/**: one note per defect category:
	- [Performance Variance](Issues/Performance%20Variance.md): *the headline defect, ~41.5% multi-core variance on M5 Max bad batches*
	- [Thermal Throttling](Issues/Thermal%20Throttling.md): design constraint on 14" M5 Max, plus how to distinguish from defect
	- [Battery Defects](Issues/Battery%20Defects.md)
	- [Hinge & Palmrest Creak](Issues/Hinge%20&%20Palmrest%20Creak.md)
	- [Display](Issues/Display.md)
	- [Other Reported Issues](Issues/Other%20Reported%20Issues.md): speakers, mic, camera, ports, Wi-Fi
	- [Repairability](Issues/Repairability.md): *context, not a defect*
- **[Sources](Sources.md)**: references for everything in this folder

## Use this as a template

When the M6 launches (or a new defect class emerges that warrants a separate calibration), copy this folder:

```bash
cp -r examples/m5-2026 examples/m6-2027
# update the notes inside, then add a target preset that points at the new dir
```

Calibrations are deliberately Markdown, meant to be read, edited, and discussed by humans, not parsed by code.

## How to use this folder

When a target preset has `"calibration_dir": "examples/m5-2026"`, this folder is the documented defect landscape for that generation. After `./run` finishes, if any phase produced WARN or FAIL, open `M5 Quality Issues.md` and cross-reference against the relevant per-issue note in `Issues/` to decide whether the signal matches a known defect class.

## Variant scope

| Variant | Most-relevant issues | Calibration applies? |
|---|---|---|
| M5 (Air, base MBP, base mini) | Battery defects, build quality, sensor issues | Yes |
| M5 Pro (MBP 14"/16", mini, Studio) | Battery defects, thermal (less severe than Max), build | Yes |
| M5 Max (MBP 14"/16", Studio, iMac Pro) | **Performance variance**, thermal throttling on 14" | Yes, primary focus |
| M5 Ultra (Studio, future) | Not yet documented; copy + extend when reports surface | Add notes |
