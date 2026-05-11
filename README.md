# Shakedown

> Verify a new Mac before your return window closes.

A Claude-Code-driven verification harness for new Apple Silicon Macs. Designed for the case where you can't easily return the unit — bought abroad, narrow window, expensive config, or you just don't want to discover a defect three months from now.

The agent runs a sequence of deterministic shell scripts (system inventory, battery health, CPU variance benchmark, sustained thermal load) and walks you through manual physical checks (display dead-pixel test, hinge / keyboard / speaker / port inspection, Apple Diagnostics). Outputs a structured PASS/FAIL report with cited evidence.

> **Why "shakedown"?** Borrowed from engineering: a *shakedown run* is the first-run stress test of new machinery before it's commissioned. Same idea, applied to your new Mac.

## Why this exists

Some Mac generations ship with batch-level defects that don't show up in a quick boot test. The [2026 M5 Max line](examples/m5-2026/M5%20Quality%20Issues.md), for example, had units showing up to **41.5% multi-core performance variance** between identical benchmark runs — a defect you can only see by running repeated load tests on a thermally-saturated chassis. A 30-second smoke test on store Wi-Fi will not catch it.

Shakedown is the procedure for catching those.

> **Status (v0.1):** the methodology has not yet been validated against a confirmed-defective unit — thresholds are derived from public reports and engineering reasoning. Expect them to tighten as crowd-sourced submissions land. Treat current results as advisory, not authoritative; if a verdict is borderline, rerun before deciding.
>
> Phase 4 uses parallel SHA-256, which is hardware-accelerated on Apple Silicon and Coffee Lake+ Intel. The variance methodology transfers cleanly to any sustained workload — the SHA choice is for zero-install portability — but the test doesn't probe integer pipelines or memory bandwidth as deeply as Cinebench / Geekbench would. A non-accelerated workload pass is on the [roadmap](#roadmap).

## Quick start

On the new Mac, with [Claude Code](https://docs.claude.com/claude-code) (the recommended runtime — see [Supported agents](#supported-agents) for alternatives):

1. **Install Xcode Command Line Tools** (provides `git`). 5–10 min, one-time. A GUI dialog will pop up:

	```bash
	xcode-select -p >/dev/null 2>&1 || xcode-select --install
	```

2. **Install Claude Code.** See [docs.claude.com/claude-code](https://docs.claude.com/claude-code) for the current install method:

	```bash
	npm install -g @anthropic-ai/claude-code
	```

3. **Clone and run.**

	```bash
	git clone https://github.com/ugglr/mac-shakedown ~/mac-shakedown && cd ~/mac-shakedown
	claude "run the QA against target mbp-16-m5-max-64"
	```

The agent walks the [runbook](Verification/Runbook.md) end to end (~45 min on a MacBook Pro, ~25 min on a fanless MacBook Air, plus an optional 30 min idle-drain test). Outputs `Reports/<timestamp>.json` and `Reports/<timestamp>.md`.

> Keep the charger plugged in for all phases except the optional idle-drain test (Phase 9).

## Supported agents

Shakedown's agent instructions live in [`AGENTS.md`](AGENTS.md), following the cross-tool convention so any sufficiently capable agent can run it. The harness needs an agent that can: run shell commands, read files, ask the user yes/no questions, and sit through ~16–20 minutes of blocking benchmarks.

| Agent | Status | Notes |
|---|---|---|
| **Claude Code** | ✅ reference runtime | `CLAUDE.md` points at `AGENTS.md` so it auto-loads. Use the [Quick start](#quick-start) above. |
| Cursor | 🟡 unverified — should work | In Composer / Agent mode, attach `AGENTS.md` to the prompt: *"Follow AGENTS.md and run the QA against target mbp-16-m5-max-64."* |
| Cline / Roo Code | 🟡 unverified — should work | Point at `AGENTS.md` in the system prompt. Same invocation as Cursor. |
| Aider | 🟡 unverified — should work | `aider --read AGENTS.md` then ask it to run the QA. |
| OpenAI Codex CLI | 🟡 unverified — should work | Recognizes `AGENTS.md` natively. Just `codex "run the QA against target mbp-16-m5-max-64"`. |
| Other | — | Anything that can run a shell + read files + chat with the user. Tell it: *"Read `AGENTS.md`. Run the QA against my Mac per the procedure described there."* |

If you've run Shakedown end-to-end with a non-Claude-Code agent, please open a PR updating the table to ✅. If you hit friction, open an issue with the agent name and what tripped — happy to clarify the runbook for any compatible runtime.

**No agent at all?** The scripts run standalone — no LLM required. Read [`Verification/Runbook.md`](Verification/Runbook.md), execute the scripts in order, answer the manual-check questions to yourself, and write the report by hand. The agent flow is convenience, not a hard dependency.

## What a run looks like

See [`examples/sample-report-illustrative/`](examples/sample-report-illustrative/) for an annotated example PASS report on a 16" M5 Max — Markdown render and the underlying JSON. (Illustrative — not a real run; replaced when crowd-sourced submissions land.)

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
| 7 | Manual physical inspection | agent prompts: hinge, keyboard, speakers, ports, Touch ID, etc. |
| 8 | Apple Diagnostics | reboot + Cmd-D |
| 9 | Optional idle drain | 30 min sleep, measure %/30 min |

## Specifying your target

Three ways:

1. **Use a preset.** `targets/*.json` has presets for common SKUs:
	- [`mbp-16-m5-max-64`](targets/mbp-16-m5-max-64.json)
	- [`mbp-14-m5-pro-24`](targets/mbp-14-m5-pro-24.json)
	- [`macbook-air-m5-16`](targets/macbook-air-m5-16.json)

	```bash
	claude "run QA against target mbp-16-m5-max-64"
	```

2. **Tell the agent.** No preset, just describe what you bought:

	```bash
	claude "run QA — I bought a 14-inch M5 Max with 36 GB"
	```

3. **No target.** The agent runs the verification and reports what it finds, without asserting against any spec.

	```bash
	claude "run QA"
	```

## Repo layout

```
mac-shakedown/
├── README.md
├── AGENTS.md                       # agent operating manual (cross-tool convention)
├── CLAUDE.md                       # one-line pointer at AGENTS.md (Claude Code auto-loader)
├── CONTRIBUTING.md
├── CHANGELOG.md
├── SECURITY.md
├── LICENSE
├── Shakedown Brain.md              # Obsidian map-of-content (optional, for vault users)
├── .github/                        # issue + PR templates, CI lint workflow
├── Verification/                   # generation-agnostic test machinery
│   ├── Runbook.md                  # the procedure
│   ├── Pass-Fail Criteria.md       # thresholds (parameterized by chassis class)
│   └── scripts/
│       ├── inventory.sh            # system_profiler + sysctl → JSON
│       ├── battery.sh              # ioreg battery health → JSON
│       ├── cpu-variance.sh         # burst + warmup + 5×60s timed iters → JSON
│       ├── thermal-load.sh         # 10-min sustained + powermetrics → JSON (sudo)
│       └── display-test.sh         # fullscreen color cycle (HTML)
├── targets/                        # preset SKU configs
│   ├── README.md
│   ├── mbp-16-m5-max-64.json
│   ├── mbp-14-m5-pro-24.json
│   └── macbook-air-m5-16.json
├── examples/                       # generation-specific calibrations + sample reports
│   ├── m5-2026/                    # the 2026 M5 generation defect landscape
│   │   ├── README.md
│   │   ├── M5 Quality Issues.md
│   │   ├── Issues/
│   │   └── Sources.md
│   └── sample-report-illustrative/ # what a real run looks like (illustrative, not from a real unit)
└── Reports/                        # output artifacts (gitignored)
    └── SCHEMA.md                   # JSON report schema (v1.0)
```

## Adding a new generation

When a new chip line ships, copy `examples/m5-2026/` to `examples/<generation>-<year>/`, document the issues there, and add a target preset pointing to it. See [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-generation-calibration).

## Manual usage (without Claude Code)

You can run the scripts directly. Set `CHASSIS_CLASS` to match your Mac (default is `active-cooled-pro` — fine for an Apple Silicon MBP, wrong for an Air or Intel Mac):

```bash
export CHASSIS_CLASS=active-cooled-pro    # or fanless | desktop | intel-laptop | intel-desktop

./Verification/scripts/inventory.sh    > Reports/inventory.json
./Verification/scripts/battery.sh      > Reports/battery.json
./Verification/scripts/cpu-variance.sh > Reports/variance.json
sudo CHASSIS_CLASS="$CHASSIS_CLASS" ./Verification/scripts/thermal-load.sh > Reports/thermal.json
./Verification/scripts/display-test.sh
```

The inline `sudo CHASSIS_CLASS=...` form preserves the env var across the privilege boundary regardless of sudoers `env_keep` config (otherwise `thermal-load.sh` falls back to `active-cooled-pro` defaults). Then read the values against [Pass-Fail Criteria](Verification/Pass-Fail%20Criteria.md). The agent flow is recommended though — most of the value is in the manual prompts and the cross-referencing against calibration notes.

## Submit a calibration report

The v0.1 thresholds need real-world data to calibrate. If you ran the harness — PASS, WARN, or FAIL — please consider submitting your report. **Especially valuable: known-good machines from someone you trust**, which is what the methodology currently lacks.

There's no hosted backend; submissions land via PR.

```bash
./Verification/scripts/run-shakedown.sh --target mbp-16-m5-max-64
```

The orchestrator runs the auto-runnable phases (preflight → inventory → battery → CPU variance → thermal load), aggregates into a SCHEMA-compliant JSON, and writes two copies:

- `Reports/local/<filename>.json` — full output, **gitignored** (keeps `_raw_*` debug fields)
- `Reports/submissions/<filename>.json` — sanitized for PR submission

To submit:

1. Skim the submission JSON for any leftover PII.
2. `git checkout -b submit-<your-date> && git add Reports/submissions/<filename>.json && git commit -m "submission: <chassis> <chip> <verdict>"`
3. Open a PR. CI runs the submission audit (rejects `_raw_*` leakage, plaintext serials, malformed schema, off-pattern filenames).

The manual phases (display, physical inspection, Apple Diagnostics, idle drain) are emitted as `skipped` placeholders. If you ran any of them, hand-edit `Reports/local/<filename>.json`, re-sanitize, and overwrite the submission copy before opening the PR.

## Roadmap

- **Hosted aggregator.** Eventually, submission via API to a public site so reports aren't reviewed by hand. Until then, the PR-submission flow above *is* the aggregator — slower but no infra, and PR review catches PII before merge.
- **Non-accelerated workload pass.** Optional Phase 4b that runs a workload without hardware acceleration (e.g. unaccelerated AES, BLAKE2b in pure Python, or a pinned matrix-multiply kernel) so the test stresses integer pipelines and memory bandwidth too. Catches batch defects that don't show up under SHA-NI / Apple Silicon's crypto engines.
- **GPU variance test.** Currently CPU-only. M5 Max GPU is the bigger thermal contributor and a Metal compute load would be much more aggressive than CPU SHA-256.
- **NVMe SSD performance.** Currently we only check SMART status — Apple has shipped 256 GB single-die SSD perf regressions on past gens, worth catching.
- **Memory bandwidth.** STREAM-style benchmark.
- **Per-core pinning.** macOS lacks public CPU affinity APIs, so we can't pin workers to specific cores. A defective single core gets averaged out across N P-cores. Reporting `worker_imbalance_pct_per_iter` is a partial mitigation; investigating workarounds (ASIA-style fence, pthread_qos hints) is on the list.
- **More generation calibrations.** Apple Silicon M1–M4 (the scripts work today; only the calibration notes and target presets need filling), Intel-era issues (T2 chip, butterfly keyboards 2018–19, GPU stutter 2019).
- **14" vs 16" thermal sub-classes.** The 14" M5 Max is documented to throttle by design under sustained Pro-class thresholds — split off `active-cooled-pro-14` and `active-cooled-pro-16` once we have data points to set the looser-but-not-too-loose thresholds.

## Origin

Built originally to vet a 16" M5 Max purchase abroad, where returning a defective unit isn't practical. The research that informs the M5 Max thresholds is in [`examples/m5-2026/`](examples/m5-2026/) — kept as a worked example of what a generation calibration looks like.

## License

MIT — see [LICENSE](LICENSE).
