# Shakedown

> Verify a new Mac before your return window closes.

A verification harness for new Macs, Apple Silicon and Intel. Built for cases where you can't easily return the unit: bought abroad, narrow return window, expensive config, or you just don't want to discover a defect three months from now.

A single command runs the automated phases (system inventory, battery health, CPU variance benchmark, sustained thermal load) end-to-end. A separate runbook walks you through the manual phases (display dead-pixel test, hinge / keyboard / speaker / port inspection, Apple Diagnostics).

> **Why "shakedown"?** Borrowed from engineering: a *shakedown run* is the first-run stress test of new machinery before it's commissioned. Same idea, applied to your new Mac.

## Why this exists

Some Mac generations ship with batch-level defects that don't show up in a quick boot test. The [2026 M5 Max line](examples/m5-2026/M5%20Quality%20Issues.md), for example, had units showing up to **41.5% multi-core performance variance** between identical benchmark runs. You can only see that by running repeated load tests on a thermally-saturated chassis. A 30-second smoke test on store Wi-Fi will not catch it.

Shakedown is the procedure for catching those.

> **Status (v0.1):** the methodology has not yet been validated against a confirmed-defective unit. Thresholds are derived from public reports and engineering reasoning. Expect them to tighten as crowd-sourced submissions land. Treat current results as advisory, not authoritative; if a verdict is borderline, rerun before deciding.
>
> Phase 4 uses parallel SHA-256, which is hardware-accelerated on Apple Silicon and Coffee Lake+ Intel. The variance methodology transfers cleanly to any sustained workload (the SHA choice is for zero-install portability), but the test doesn't probe integer pipelines or memory bandwidth as deeply as Cinebench / Geekbench would. A non-accelerated workload pass is on the [roadmap](#roadmap).

## Quick start

1. **Install Xcode Command Line Tools** (provides `git`, 5–10 min one-time; a GUI dialog pops up):

	```bash
	xcode-select -p >/dev/null 2>&1 || xcode-select --install
	```

2. **Clone and run.**

	```bash
	git clone https://github.com/ugglr/mac-shakedown ~/mac-shakedown && cd ~/mac-shakedown
	./run --target mbp-16-m5-max-64
	```

Or without a preset, which auto-detects chassis class from `system_profiler` (fine for Macs that don't have a target preset yet):

```bash
./run
```

The orchestrator runs the four automated phases (preflight → inventory → battery → CPU variance → thermal load), asks for sudo once upfront (Phase 5 needs `powermetrics`), and writes a SCHEMA-compliant report to `Reports/local/` plus a sanitized PR-able copy to `Reports/submissions/`. Runtime ~18 min on Intel, ~25 min on Air, ~45 min on MacBook Pro.

`./run --no-sudo` skips the 10-min thermal phase (the only phase that needs sudo) for a half-runtime no-password variance-only pass.

> Keep the charger plugged in for all phases.

**For the manual phases** (display test, hinge / keyboard / speaker / port inspection, Apple Diagnostics, optional 30-min idle drain), follow [`Verification/Runbook.md`](Verification/Runbook.md) phases 6–9 by hand.

## What a run looks like

See [`examples/sample-report-illustrative/`](examples/sample-report-illustrative/) for an annotated example PASS report on a 16" M5 Max: Markdown render and the underlying JSON. (Illustrative, not a real run, replaced when crowd-sourced submissions land.)

## What gets checked

| Phase | What | How |
|---|---|---|
| 0 | Pre-flight & quiet-system check | `uptime`, `top` |
| 1 | Hardware identity vs. target | `system_profiler` + `sysctl` → `inventory.sh` |
| 2 | Battery health (cycles, capacity, condition) | `ioreg AppleSmartBattery` → `battery.sh` |
| 3 | Sensor & port inventory | (uses Phase 1 output) |
| 4 | **CPU performance variance** | 5 s burst + chassis-class-aware warmup (300 s on Pro, 60 s on Air) + 5 × 60 s timed iterations, parallel SHA-256 → `cpu-variance.sh` |
| 5 | Sustained thermal load (chassis-class-aware thresholds) | 10 min continuous + `powermetrics` sampling → `thermal-load.sh` |
| 6 | Display visual inspection | fullscreen color cycle in Safari → `display-test.sh` |
| 7 | Manual physical inspection | hinge, keyboard, speakers, ports, Touch ID, etc. (runbook checklist) |
| 8 | Apple Diagnostics | reboot + Cmd-D |
| 9 | Optional idle drain | 30 min sleep, measure %/30 min |

## Specifying your target

Two ways:

1. **Use a preset.** `targets/*.json` has presets for common SKUs:
	- [`mbp-16-m5-max-64`](targets/mbp-16-m5-max-64.json)
	- [`mbp-14-m5-pro-24`](targets/mbp-14-m5-pro-24.json)
	- [`macbook-air-m5-16`](targets/macbook-air-m5-16.json)
	- [`mbp-16-intel-2019`](targets/mbp-16-intel-2019.json)

	```bash
	./run --target mbp-16-m5-max-64
	```

	Hard-fails if the chip / RAM don't match the preset. Useful when verifying you got the SKU you paid for.

2. **No target.** Auto-detects chassis class, skips the SKU asserts, still runs all the variance / thermal / battery checks:

	```bash
	./run
	```

	Use this for Macs that don't have a preset yet, or existing units you're self-testing rather than verifying as new.

(Don't see your SKU? `targets/README.md` has the schema. Open a PR adding a preset.)

## Repo layout

```
mac-shakedown/
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── SECURITY.md
├── LICENSE
├── run                             # convenience entry point, execs the orchestrator
├── Shakedown Brain.md              # Obsidian map-of-content (optional, for vault users)
├── .github/                        # issue + PR templates, CI lint workflow
├── Verification/                   # generation-agnostic test machinery
│   ├── Runbook.md                  # the procedure
│   ├── Pass-Fail Criteria.md       # thresholds (parameterized by chassis class)
│   └── scripts/
│       ├── run-shakedown.sh        # the orchestrator (`./run` execs this)
│       ├── inventory.sh            # system_profiler + sysctl → JSON
│       ├── battery.sh              # ioreg battery health → JSON
│       ├── cpu-variance.sh         # burst + warmup + 5×60s timed iters → JSON
│       ├── thermal-load.sh         # 10-min sustained + powermetrics → JSON (sudo)
│       └── display-test.sh         # fullscreen color cycle (HTML)
├── targets/                        # preset SKU configs
│   ├── README.md
│   ├── mbp-16-m5-max-64.json
│   ├── mbp-14-m5-pro-24.json
│   ├── macbook-air-m5-16.json
│   └── mbp-16-intel-2019.json
├── examples/                       # generation-specific calibrations + sample reports
│   ├── m5-2026/                    # the 2026 M5 generation defect landscape
│   │   ├── README.md
│   │   ├── M5 Quality Issues.md
│   │   ├── Issues/
│   │   └── Sources.md
│   └── sample-report-illustrative/ # what a real run looks like (illustrative, not from a real unit)
└── Reports/                        # output artifacts
    ├── SCHEMA.md                   # JSON report schema (v1.0)
    ├── local/                      # full output, gitignored
    └── submissions/                # sanitized, PR-able copies
```

## Adding a new generation

When a new chip line ships, copy `examples/m5-2026/` to `examples/<generation>-<year>/`, document the issues there, and add a target preset pointing to it. See [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-generation-calibration).

## Running individual scripts (advanced)

`./run` orchestrates the five script-driven phases. If you want to rerun a single phase, say to confirm a borderline variance warn without redoing the whole 18-min pass, call the scripts directly:

```bash
export CHASSIS_CLASS=active-cooled-pro    # or fanless | desktop | intel-laptop | intel-desktop

./Verification/scripts/inventory.sh    > Reports/inventory.json
./Verification/scripts/battery.sh      > Reports/battery.json
./Verification/scripts/cpu-variance.sh > Reports/variance.json
sudo CHASSIS_CLASS="$CHASSIS_CLASS" ./Verification/scripts/thermal-load.sh > Reports/thermal.json
./Verification/scripts/display-test.sh
```

The inline `sudo CHASSIS_CLASS=...` form preserves the env var across the privilege boundary regardless of sudoers `env_keep` config. Read the values against [Pass-Fail Criteria](Verification/Pass-Fail%20Criteria.md).

## Submit a calibration report

The v0.1 thresholds need real-world data to calibrate. If you ran the harness (PASS, WARN, or FAIL), please consider submitting your report. **Known-good machines from someone you trust are the most valuable submissions**, since that's what the methodology currently lacks.

`./run` already writes the sanitized copy to `Reports/submissions/<filename>.json`. To submit it:

1. Skim the JSON for any leftover PII (free-form notes, store name, etc.).
2. `git checkout -b submit-<your-date> && git add Reports/submissions/<filename>.json && git commit -m "submission: <chassis> <chip> <verdict>"`
3. Open a PR. CI runs the submission audit and rejects `_raw_*` leakage, plaintext serials, malformed schema, or off-pattern filenames.

The manual phases (display, physical inspection, Apple Diagnostics, idle drain) land as `skipped` placeholders. If you ran any of them, hand-edit `Reports/local/<filename>.json` to fill in the results, re-sanitize, and overwrite the submission copy before the PR.

## Roadmap

- **Hosted aggregator.** Eventually, submission via API to a public site so reports aren't reviewed by hand. Until then, the PR-submission flow above *is* the aggregator. Slower, but no infra, and PR review catches PII before merge.
- **Non-accelerated workload pass.** Optional Phase 4b that runs a workload without hardware acceleration (e.g. unaccelerated AES, BLAKE2b in pure Python, or a pinned matrix-multiply kernel) so the test stresses integer pipelines and memory bandwidth too. Catches batch defects that don't show up under SHA-NI / Apple Silicon's crypto engines.
- **GPU variance test.** Currently CPU-only. M5 Max GPU is the bigger thermal contributor and a Metal compute load would be much more aggressive than CPU SHA-256.
- **NVMe SSD performance.** Currently we only check SMART status. Apple has shipped 256 GB single-die SSD perf regressions on past gens, worth catching.
- **Memory bandwidth.** STREAM-style benchmark.
- **Per-core pinning.** macOS lacks public CPU affinity APIs, so we can't pin workers to specific cores. A defective single core gets averaged out across N P-cores. Reporting `worker_imbalance_pct_per_iter` is a partial mitigation; investigating workarounds (ASIA-style fence, pthread_qos hints) is on the list.
- **More generation calibrations.** Apple Silicon M1–M4 (the scripts work today; only the calibration notes and target presets need filling), Intel-era issues (T2 chip, butterfly keyboards 2018–19, GPU stutter 2019).
- **14" vs 16" thermal sub-classes.** The 14" M5 Max is documented to throttle by design under sustained Pro-class thresholds. Split off `active-cooled-pro-14` and `active-cooled-pro-16` once we have data points to set the looser-but-not-too-loose thresholds.

## Origin

Built originally to vet a 16" M5 Max purchase abroad, where returning a defective unit isn't practical. The research that informs the M5 Max thresholds is in [`examples/m5-2026/`](examples/m5-2026/), kept as a worked example of what a generation calibration looks like.

## License

MIT. See [LICENSE](LICENSE).
