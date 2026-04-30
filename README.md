# Shakedown

> Verify a new Mac before your return window closes.

A Claude-Code-driven verification harness for new Apple Silicon Macs. Designed for the case where you can't easily return the unit — bought abroad, narrow window, expensive config, or you just don't want to discover a defect three months from now.

The agent runs a sequence of deterministic shell scripts (system inventory, battery health, CPU variance benchmark, sustained thermal load) and walks you through manual physical checks (display dead-pixel test, hinge / keyboard / speaker / port inspection, Apple Diagnostics). Outputs a structured PASS/FAIL report with cited evidence.

> **Why "shakedown"?** Borrowed from engineering: a *shakedown run* is the first-run stress test of new machinery before it's commissioned. Same idea, applied to your new Mac.

## Why this exists

Some Mac generations ship with batch-level defects that don't show up in a quick boot test. The [2026 M5 Max line](examples/m5-max-2026/M5%20Quality%20Issues.md), for example, had units showing up to **41.5% multi-core performance variance** between identical benchmark runs — a defect you can only see by running repeated load tests on a thermally-saturated chassis. A 30-second smoke test on store Wi-Fi will not catch it.

Shakedown is the procedure for catching those.

## Quick start

On the new Mac, with [Claude Code](https://docs.claude.com/claude-code) (the recommended runtime — see [Supported agents](#supported-agents) for alternatives):

```bash
xcode-select -p >/dev/null 2>&1 || xcode-select --install
# wait for Command Line Tools to install (5–10 min, GUI prompt), then:

# Install Claude Code — see https://docs.claude.com/claude-code for current method
npm install -g @anthropic-ai/claude-code

git clone https://github.com/ugglr/mac-shakedown ~/mac-shakedown && cd ~/mac-shakedown
claude "run the QA against target mbp-16-m5-max-64"
```

The agent walks the [runbook](Verification/Runbook.md) end to end (~40 min, plus an optional 30 min idle-drain test). Outputs `Reports/<timestamp>.json` and `Reports/<timestamp>.md`.

> Keep the charger plugged in for all phases except the optional idle-drain test (Phase 9).

## Supported agents

Shakedown's agent instructions live in [`AGENTS.md`](AGENTS.md), following the cross-tool convention so any sufficiently capable agent can run it. The harness needs an agent that can: run shell commands, read files, ask the user yes/no questions, and sit through ~16 minutes of blocking benchmarks.

| Agent | Notes |
|---|---|
| **Claude Code** *(recommended)* | Reference runtime. `CLAUDE.md` points at `AGENTS.md` so it auto-loads. Use the [Quick start](#quick-start) above. |
| Cursor | In Composer / Agent mode, attach `AGENTS.md` to the prompt: *"Follow AGENTS.md and run the QA against target mbp-16-m5-max-64."* |
| Cline / Roo Code | Point at `AGENTS.md` in the system prompt. Same invocation as Cursor. |
| Aider | `aider --read AGENTS.md` then ask it to run the QA. |
| OpenAI Codex CLI | Recognizes `AGENTS.md` natively. Just `codex "run the QA against target mbp-16-m5-max-64"`. |
| Other | Anything that can run a shell + read files + chat with the user. Tell it: *"Read `AGENTS.md`. Run the QA against my Mac per the procedure described there."* |

**No agent at all?** The scripts run standalone — no LLM required. Read [`Verification/Runbook.md`](Verification/Runbook.md), execute the scripts in order, answer the manual-check questions to yourself, and write the report by hand. The agent flow is convenience, not a hard dependency.

## What gets checked

| Phase | What | How |
|---|---|---|
| 0 | Pre-flight & quiet-system check | `uptime`, `top` |
| 1 | Hardware identity vs. target | `system_profiler` + `sysctl` → `inventory.sh` |
| 2 | Battery health (cycles, capacity, condition) | `ioreg AppleSmartBattery` → `battery.sh` |
| 3 | Sensor & port inventory | (uses Phase 1 output) |
| 4 | **CPU performance variance** | 90 s warmup + 5 × 60 s timed iterations, parallel SHA-256 → `cpu-variance.sh` |
| 5 | Sustained thermal load | 10 min continuous + `powermetrics` sampling → `thermal-load.sh` |
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
shakedown/
├── README.md
├── CLAUDE.md                       # agent operating manual (auto-loaded)
├── CONTRIBUTING.md
├── LICENSE
├── Shakedown Brain.md              # Obsidian map-of-content (optional, for vault users)
├── Verification/                   # generation-agnostic test machinery
│   ├── Runbook.md                  # the procedure
│   ├── Pass-Fail Criteria.md       # thresholds
│   └── scripts/
│       ├── inventory.sh            # system_profiler + sysctl → JSON
│       ├── battery.sh              # ioreg battery health → JSON
│       ├── cpu-variance.sh         # parallel-hash, time-capped iters → JSON
│       ├── thermal-load.sh         # 10-min sustained + powermetrics → JSON (sudo)
│       └── display-test.sh         # fullscreen color cycle (HTML)
├── targets/                        # preset SKU configs
│   ├── README.md
│   ├── mbp-16-m5-max-64.json
│   ├── mbp-14-m5-pro-24.json
│   └── macbook-air-m5-16.json
├── examples/                       # generation-specific calibrations
│   └── m5-max-2026/                # known issues, sources, thresholds for 2026 M5 generation
│       ├── README.md
│       ├── M5 Quality Issues.md
│       ├── Issues/
│       └── Sources.md
└── Reports/                        # output artifacts (gitignored)
    └── SCHEMA.md                   # JSON report schema (v1.0)
```

## Adding a new generation

When a new chip line ships, copy `examples/m5-max-2026/` to `examples/<generation>-<year>/`, document the issues there, and add a target preset pointing to it. See [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-generation-calibration).

## Manual usage (without Claude Code)

You can run the scripts directly:

```bash
./Verification/scripts/inventory.sh      > Reports/inventory.json
./Verification/scripts/battery.sh        > Reports/battery.json
./Verification/scripts/cpu-variance.sh   > Reports/variance.json
sudo ./Verification/scripts/thermal-load.sh > Reports/thermal.json
./Verification/scripts/display-test.sh
```

Then read the values against [Pass-Fail Criteria](Verification/Pass-Fail%20Criteria.md). The agent flow is recommended though — most of the value is in the manual prompts and the cross-referencing against calibration notes.

## Roadmap

- **Hosted aggregator.** Submit your `Reports/<ts>.json` to a public site for crowd-sourced baselines per generation. Once we have N submissions from known-good units, the "baseline TBD" caveat in the variance test goes away. (See [`Reports/SCHEMA.md`](Reports/SCHEMA.md) — reports are designed for opt-in submission.)
- **More generation calibrations.** M6, M7, etc. as they land.
- **GPU variance test.** Currently CPU-only.

## Origin

Built originally to vet a 16" M5 Max purchase abroad, where returning a defective unit isn't practical. The research that informs the M5 Max thresholds is in [`examples/m5-max-2026/`](examples/m5-max-2026/) — kept as a worked example of what a generation calibration looks like.

## License

MIT — see [LICENSE](LICENSE).
