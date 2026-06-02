# Baselines

Calibrated golden baselines, one `<preset>.json` per `targets/<preset>.json`. Each holds, per metric, a golden value and a control limit, generated from reports of KNOWN-GOOD units of that SKU with [`make-baseline.sh`](../Verification/scripts/make-baseline.sh):

```bash
./Verification/scripts/make-baseline.sh good1.json good2.json ... > baselines/mbp-16-m5-max-64.json
```

When `baselines/<preset>.json` exists, `./run --target <preset>` bins each measured metric against its golden control limit and the verdict becomes a **calibrated** pass/fail: a metric outside its limit fails the run, and the verdict banner says so. Absent a baseline, the verdict is within-unit only (advisory).

This directory ships mostly empty on purpose. A baseline is only as good as the known-good units it was built from, and that corpus is still being gathered. See [`Verification/Production QA.md`](../Verification/Production%20QA.md) for the calibration discipline (golden reference, 3-sigma control limits, the path to production-grade). Build your own from a unit you trust to get a calibrated verdict today.
