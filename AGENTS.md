# Shakedown — Agent Operating Manual

You are operating inside **Shakedown**, an open-source Mac verification harness. The user is verifying a new Apple Silicon Mac (typically right after purchase, often before they can easily return it). Your job is to run the runbook against the unit and produce a structured PASS/FAIL report with evidence.

The name is borrowed from engineering — a *shakedown run* is the first-run stress test of new machinery before commissioning. Same concept here.

> This file follows the [`AGENTS.md`](https://agents.md) convention so any agent that supports it can pick up these instructions. **Claude Code is the reference / recommended runtime** — it's what Shakedown is primarily developed against — but Cursor, Cline, Aider, OpenAI Codex CLI, etc. should all work as long as they can run shell commands, read files, and ask the user yes/no questions.

## When the user asks you to "run QA" / "verify this Mac" / similar

1. **Resolve the target.** Three cases:
	- *User specified a preset* (e.g. `--target mbp-16-m5-max-64`, or "against target X"): load `targets/<name>.json` and use those assertions.
	- *User described the unit verbally* (e.g. "I bought a 14-inch M5 Max with 36 GB"): construct an in-memory target with those fields. Don't write a preset file.
	- *User didn't specify*: ask once — "What chip, RAM, and chassis size did you buy?" Then use those.
	- *User says "just verify it"*: run with no assertions, report the actual unit specs.

2. **Read the calibration.** If the target has `calibration_dir` (e.g. `examples/m5-2026`), read its `<Generation> Quality Issues.md` overview before starting. This gives you the defect landscape to cross-reference findings against.

3. **Walk the runbook.** [`Verification/Runbook.md`](Verification/Runbook.md) end to end. Don't skip phases without explicit user permission. One phase at a time, surface findings as you go.

4. **Write evidence.** Final outputs:
	- `Reports/<ISO-timestamp>.json` — canonical machine-readable report (schema in [`Reports/SCHEMA.md`](Reports/SCHEMA.md))
	- `Reports/<ISO-timestamp>.md` — human-readable render of the JSON

## Operating principles

1. **Be the harness.** Run the scripts in `Verification/scripts/`, capture stdout, parse the JSON, write evidence. Don't reimplement what the scripts already do.

2. **Lead the manual checks.** For physical inspection (hinge creak, palmrest flex, dead pixels, every keyboard key, listen for speaker crackle), prompt the user with a clear, single yes/no question and record the answer. Don't assume; ask. One question at a time when possible.

3. **Stop on critical mismatch.** If the unit doesn't match the target's `chip_pattern`, `memory_gb`, or `model_must_include`, surface it immediately and ask whether to continue. There's no point benchmarking the wrong unit.

4. **Cite the calibration.** When a finding maps to a documented issue (e.g. high CPU variance → bad-batch issue), link the relevant note in the calibration's `Issues/` folder. Don't paraphrase from memory; quote the specific note.

5. **Pass `CHASSIS_CLASS` to the load tests.** The variance and thermal scripts both accept `CHASSIS_CLASS={fanless|active-cooled-pro|desktop|intel-laptop|intel-desktop}` as an env var; pull it from the target preset's `thermal_chassis_class` field and export before invoking. This sets warmup duration (Phase 4) and thermal thresholds (Phase 5). Default if unset: `active-cooled-pro`.

6. **Sudo once, early.** `thermal-load.sh` needs sudo for `powermetrics`. Prompt the user once at the start of Phase 5 (`sudo -v`), and use `sudo -E ./Verification/scripts/thermal-load.sh` so the `CHASSIS_CLASS` env var crosses the privilege boundary. Don't ask for sudo again mid-run.

7. **Clear PASS / FAIL.** Final line of the report and final line in chat: `RESULT: PASS` or `RESULT: FAIL — <one-line reason>`. The user is often on a clock. Don't bury the lede.

8. **Long-running phases.** Phase 4 (~10 min on Pro / ~6 min on Air) and Phase 5 (~10 min) are blocking. Run in foreground, stream stderr progress, parse the final JSON. Together they're ~16–20 min of continuous CPU load — well past thermal saturation, which is the point.

9. **No cooldown between Phase 4 and Phase 5.** Variance test ends with a hot chassis, which is the correct starting state for the sustained thermal test. Run them back-to-back.

10. **System must be quiet before Phase 4.** Background CPU activity steals P-cores from the benchmark and produces fake variance. Before launching `cpu-variance.sh`, run `uptime` and `top -l 1 -n 5 -o cpu | tail -7`. If load average is high or any non-system process is using > 5% CPU, ask the user to close it. On a fresh out-of-box unit this is automatic.

11. **Phase 4 rerun-on-warn (decision tree).** A single warn could be background noise; act on the rerun:
	- First run `pass` → record and continue.
	- First run `warn` → rerun once. Then:
		- Second run `pass` → record as pass; mention the original warn in the report's notes.
		- Second run `warn` → record as **fail** (compound evidence across runs).
		- Second run `fail` → record as **fail**.
	- First run `fail` → record as fail; do not rerun (a single fail is signal enough).
	No third run. Two warns is the limit; the cost of running a third can mask thermal-paste defects that worsen with each iteration.

12. **Trust the script's data_quality field.** `thermal-load.sh` emits `data_quality: "no_samples" | "few_samples" | "ok"`. `no_samples` is automatically `verdict: "fail"` regardless of other metrics — don't override it just because no temp/freq numbers came through.

13. **Phase 8 requires a reboot.** Apple Diagnostics needs the user to power off and hold the power button. Before the reboot, **write a partial JSON+MD report** so progress isn't lost. After reboot, the user resumes the agent (e.g. `claude continue` for Claude Code, or however your runtime resumes a session) and tells you the diagnostic result; you append it and finalize.

14. **Submission-safe by default — but verify, don't assume.** The JSON report has `submission_safe: true` and a hashed serial. Before submitting to the future aggregator, **explicitly check**:
	- `inventory.json.summary.serial_number` is absent (only `serial_hash` is present). If `serial_number` is there, the user ran with `INCLUDE_PLAINTEXT_SERIAL=1` — set `submission_safe: false`.
	- `battery.json.battery_serial` is absent (only `battery_serial_hash`).
	- `_raw_*` blocks are stripped from the canonical submission JSON (they may contain paired Bluetooth IDs, Wi-Fi SSIDs, USB device serials).
	- Free-form user notes don't contain identifying info (store name, employee name, etc.). If they do, set `submission_safe: false` and warn the user.

	The hash is for **deduplication, not anonymization** — Apple's serial number space has limited entropy, so a determined aggregator could rainbow-table the original. Treat the hashing as obfuscation; treat `submission_safe: true` as "no plaintext PII," not "untraceable."

## Thermal chassis class — what each setting does

Set on the target via `thermal_chassis_class`. Pass through to scripts as `CHASSIS_CLASS` env var.

- **`fanless`** (Apple Silicon MacBook Air): expect aggressive throttling under sustained load by design. `cpu-variance.sh` uses 60 s warmup. `thermal-load.sh` thresholds: steady-state ≥ 50% of peak (don't fail on throttle alone), no fan-ramp expectation.
- **`active-cooled-pro`** (Apple Silicon MacBook Pro 14"/16"): standard thresholds. `cpu-variance.sh` uses 300 s warmup (16" saturation is 5–8 min). `thermal-load.sh` thresholds: steady-state ≥ 70% of peak, fan ramp expected.
- **`desktop`** (Apple Silicon Mac mini / Studio / iMac): strictest. `cpu-variance.sh` uses 180 s warmup. `thermal-load.sh` thresholds: steady-state ≥ 90% of peak; on `desktop`, **fan-doesn't-engage is a fail** (not warn). Throttling on a desktop is a real defect.
- **`intel-laptop`** (Intel MacBook Pro / Air): looser thresholds — Intel laptops throttle hard by design. 180 s warmup. Steady-state ≥ 50% of peak. `thermal-load.sh` parses Intel-format powermetrics output (per-CPU frequency, Package Power, IA Cores Power).
- **`intel-desktop`** (Intel iMac / Mac mini): tighter than `intel-laptop` but looser than Apple Silicon `desktop`. 180 s warmup. Steady-state ≥ 75% of peak.

If `thermal_chassis_class` isn't set, default to `active-cooled-pro`. Full threshold tables live in [Pass-Fail Criteria](Verification/Pass-Fail%20Criteria.md).

## Background reading

- [`examples/m5-2026/M5 Quality Issues.md`](examples/m5-2026/M5%20Quality%20Issues.md) — example calibration / defect landscape for the 2026 M5 generation
- [`Verification/Runbook.md`](Verification/Runbook.md) — the procedure
- [`Verification/Pass-Fail Criteria.md`](Verification/Pass-Fail%20Criteria.md) — thresholds
- [`Reports/SCHEMA.md`](Reports/SCHEMA.md) — JSON report schema
