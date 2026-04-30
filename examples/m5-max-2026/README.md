# Calibration: M5 Max (2026)

Worked example for verifying a 2026-generation Apple Silicon MacBook Pro, with an emphasis on the M5 Max-specific batch defects reported through Q1 2026.

This folder is **input to the agent** — it reads `M5 Quality Issues.md` and the per-issue notes in `Issues/` to interpret findings against documented batch defects, and to cite specific issues in failure reports.

## What's documented here

- **[M5 Quality Issues](M5%20Quality%20Issues.md)** — overview / map of content for this generation
- **Issues/** — one note per defect category:
	- [Performance Variance](Issues/Performance%20Variance.md) — *the headline defect: ~41.5% multi-core variance on bad batches*
	- [Thermal Throttling](Issues/Thermal%20Throttling.md)
	- [Battery Defects](Issues/Battery%20Defects.md)
	- [Hinge & Palmrest Creak](Issues/Hinge%20&%20Palmrest%20Creak.md)
	- [Display](Issues/Display.md)
	- [Other Reported Issues](Issues/Other%20Reported%20Issues.md)
	- [Repairability](Issues/Repairability.md) — *context, not a defect*
- **[Sources](Sources.md)** — references for everything in this folder

## Use this as a template

When the M6 launches (or a new defect class emerges in M5), copy this folder:

```bash
cp -r examples/m5-max-2026 examples/m6-max-2027
# update the notes inside, then add a target preset that points at the new dir
```

Calibrations are deliberately Markdown — they're meant to be read, edited, and discussed by humans, not parsed by code. The agent reads them via Claude Code's normal file-reading and applies judgment.

## How the agent uses this folder

When a target preset has `"calibration_dir": "examples/m5-max-2026"`, the agent:
1. Reads `M5 Quality Issues.md` at session start to understand the defect landscape for this generation.
2. Cross-references findings against `Issues/<topic>.md` when a phase produces a WARN or FAIL.
3. Cites the relevant note in the final report so the user has supporting evidence.
