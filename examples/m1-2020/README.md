# Calibration: M1 generation (2020-2022)

Worked example covering the first Apple Silicon generation: `Apple M1`, `M1 Pro`, `M1 Max`, and `M1 Ultra` across MacBook Air, MacBook Pro 13", MacBook Pro 14"/16", Mac mini, Mac Studio, and the 24" iMac. By Apple-laptop standards this was a relatively clean launch (no butterfly-keyboard or Flexgate-scale mechanical defect), so the documented problems cluster in two places where the data is strongest: display assemblies (the 24" iMac line failure is the standout, plus pink-tint/lines on the M1 Air and 13" Pro) and connectivity/firmware quirks (external-display kernel panics, USB-hub and external-SSD dropouts, Bluetooth and Wi-Fi flakiness, SD-card reader oddities) that were mostly resolved by macOS point releases. The infamous "SSD wear" scare turned out to be a SMART reporting error corrected in macOS 11.4, not drives dying, so it is context, not a defect.

This folder is **the reference material for failure analysis**. When `./run` produces a WARN or FAIL on a Mac whose target preset points here, read `M1 Quality Issues.md` and the relevant per-issue note to interpret the finding against documented batch defects.

## What's documented here

- **[M1 Quality Issues](M1%20Quality%20Issues.md)**: overview / map of content for this generation
- **Issues/**: one note per confirmed or credible defect:
	- [24in iMac Display Lines](Issues/24in%20iMac%20Display%20Lines.md): *the headline defect, high-voltage flex-cable degradation appearing just past warranty*
	- [MacBook Air Display Lines and Pink Tint](Issues/MacBook%20Air%20Display%20Lines%20and%20Pink%20Tint.md): cable/T-CON pink flicker and lines on the M1 Air and 13" Pro
	- [Speaker Crackle](Issues/Speaker%20Crackle.md): 2021 14"/16" Pro audio crackle and pop
	- [External Display Kernel Panics](Issues/External%20Display%20Kernel%20Panics.md): iomfb/DCP firmware panics on multi-monitor and HDMI
	- [USB Hub and External SSD Dropouts](Issues/USB%20Hub%20and%20External%20SSD%20Dropouts.md): Monterey-era disconnects
	- [Bluetooth Connectivity](Issues/Bluetooth%20Connectivity.md): Big Sur launch-window mouse/keyboard dropouts
	- [Wi-Fi After Wake](Issues/Wi-Fi%20After%20Wake.md): Big Sur drops and slow throughput after sleep
	- [SD Card Reader](Issues/SD%20Card%20Reader.md): 2021 14"/16" card-recognition flakiness
	- [SSD Wear Reporting](Issues/SSD%20Wear%20Reporting.md): *the corrected SMART reporting artifact, not a hardware fault*
- **[Sources](Sources.md)**: references for everything in this folder

## How to use this folder

When a target preset has `"calibration_dir": "examples/m1-2020"`, this folder is the documented defect landscape for that generation. After `./run` finishes, if any phase produced WARN or FAIL, open `M1 Quality Issues.md` and cross-reference against the relevant per-issue note in `Issues/` to decide whether the signal matches a known defect class. The M1 defect set is overwhelmingly display-assembly and connectivity/firmware, so the manual display inspection (Phase 6) and functional port/peripheral checks (Phase 7) carry more weight here than the thermal and variance phases.

## Variant scope

| Variant | Most-relevant issues | Calibration applies? |
|---|---|---|
| M1 (Air, 13" Pro, mini, 24" iMac) | 24" iMac display lines, Air/13" pink tint and lines, Bluetooth/Wi-Fi on Big Sur, USB-hub dropouts, SSD-wear context | Yes, primary focus |
| M1 Pro / M1 Max (MBP 14"/16") | Speaker crackle, external-display kernel panics, SD-card reader, USB-hub dropouts | Yes |
| M1 Max / M1 Ultra (Mac Studio) | External-display kernel panics, USB-hub dropouts; non-upgradeable SSD is design context | Yes |
