## Summary

<!-- What does this PR change, and why? 1–3 sentences. -->

## Type of change

- [ ] Target preset (`targets/*.json`)
- [ ] Generation calibration (`examples/<gen>-<year>/`)
- [ ] Script improvement (`Verification/scripts/`)
- [ ] Methodology change (runbook / pass-fail thresholds)
- [ ] Docs
- [ ] OSS hygiene (CI, templates, lint, etc.)

## Validation

If this changes a script or threshold, paste the JSON output of running the affected script on your Mac, plus your chip / RAM:

<!-- e.g. M5 Max, 64 GB -->

```json

```

## Checklist

- [ ] Schema version bumped in `Reports/SCHEMA.md` (if methodology changed)
- [ ] Calibration source cited in `examples/<gen>-<year>/Sources.md` (if a threshold was tweaked)
- [ ] `shellcheck Verification/scripts/*.sh` clean (run locally)
