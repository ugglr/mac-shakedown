# Calibration: M4 generation (2024-2025)

Worked example covering the 2024-2025 Apple Silicon M4 generation, `Apple M4`, `M4 Pro`, and `M4 Max` across MacBook Air, MacBook Pro 14"/16", Mac mini, Mac Studio, and iMac. This was a relatively clean generation: there is no headline batch defect like the M5 Max performance variance. What surfaced instead clusters around a version-gated JIT kernel panic (fixed in macOS 15.2), and two low-severity peripheral interactions (Mac mini Wi-Fi near metal docks, and Thunderbolt 5 single-cable portable monitors). Defects cluster where the data says, mostly OS/firmware and RF/peripheral edges, not silicon or build quality.

This folder is **the reference material for failure analysis**. When `./run` produces a WARN or FAIL on a Mac whose target preset points here, read `M4 Quality Issues.md` and the relevant per-issue note to interpret the finding against documented batch defects.

## What's documented here

- **[M4 Quality Issues](M4%20Quality%20Issues.md)**: overview / map of content for this generation
- **Issues/**: one note per documented defect:
	- [M4 JIT Kernel Panic](Issues/M4%20JIT%20Kernel%20Panic.md): *full system panic on macOS 15.0-15.1 under JIT workloads, fixed in 15.2*
	- [Mac mini Wi-Fi Near Docks](Issues/Mac%20mini%20Wi-Fi%20Near%20Docks.md): throughput loss when the unit sits on or near metal docks/drives
	- [Thunderbolt 5 Portable Monitor Power](Issues/Thunderbolt%205%20Portable%20Monitor%20Power.md): bus-powered single-cable monitors fail to power on TB5 ports
- **[Sources](Sources.md)**: references for everything in this folder

## How to use this folder

When a target preset has `"calibration_dir": "examples/m4-2024"`, this folder is the documented defect landscape for that generation. After `./run` finishes, if any phase produced WARN or FAIL, open `M4 Quality Issues.md` and cross-reference against the relevant per-issue note in `Issues/` to decide whether the signal matches a known defect class. Note that the most serious M4 issue (the JIT kernel panic) is OS-version-gated and not detectable by the harness, so for this generation most of the value is context: confirming a finding is a known peripheral edge rather than a silicon problem.

## Variant scope

| Variant | Most-relevant issues | Calibration applies? |
|---|---|---|
| M4 (Air, base MBP, base mini, iMac) | JIT kernel panic (15.0-15.1), Mac mini Wi-Fi near docks | Yes |
| M4 Pro (MBP 14"/16", mini, Studio) | JIT kernel panic, Mac mini Wi-Fi near docks, TB5 portable monitor power | Yes |
| M4 Max (MBP 14"/16", Studio) | JIT kernel panic, TB5 portable monitor power | Yes |
