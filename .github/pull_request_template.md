## Summary

<!-- What does this PR change, and why? 1–3 sentences. -->

## Type of change

- [ ] **Calibration report submission** (`Reports/submissions/*.json`; see below)
- [ ] Target preset (`targets/*.json`)
- [ ] Generation calibration (`examples/<gen>-<year>/`)
- [ ] Script improvement (`Verification/scripts/`)
- [ ] Methodology change (runbook / pass-fail thresholds)
- [ ] Docs
- [ ] OSS hygiene (CI, templates, lint, etc.)

## Calibration report submission (skip if not applicable)

- [ ] I generated this via `./Verification/scripts/run-shakedown.sh --target <preset>` (not hand-rolled)
- [ ] I reviewed the submission JSON and confirmed no plaintext PII (serial, SSID, store name)
- [ ] Chip / RAM / chassis class: <!-- e.g. M5 Max / 64 GB / active-cooled-pro -->
- [ ] Overall verdict: <!-- PASS / FAIL -->

## Validation

If this changes a script or threshold, paste the JSON output of running the affected script on your Mac, plus your chip / RAM:

<!-- e.g. M5 Max, 64 GB -->

```json

```

## Checklist

- [ ] Schema version bumped in `Reports/SCHEMA.md` (if methodology changed)
- [ ] Calibration source cited in `examples/<gen>-<year>/Sources.md` (if a threshold was tweaked)
- [ ] `shellcheck Verification/scripts/*.sh` clean (run locally)
