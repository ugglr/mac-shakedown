---
created: 2026-04-30
tags: [verification, runbook]
---

# QA Runbook

The procedure followed by the agent (or by a human running manually). Each phase has a goal, an action, and a pass condition. See [Pass-Fail Criteria](Pass-Fail%20Criteria.md) for the consolidated thresholds and [the JSON report schema](../Reports/SCHEMA.md) for the canonical output format.

**Total time:** ~45 min on a MacBook Pro, ~25 min on a fanless Air, ~35 min on a desktop or Intel Mac, +30 min if you opt into the idle-drain test.

> **Reads target from:** the user's invocation. If they passed `--target <name>` or "against target X", the agent loads `targets/<name>.json` and uses those assertions for Phase 1. Otherwise the agent asks for chip / RAM / chassis at start, or runs without assertions if the user opts out.

## Phase 0 — Pre-flight (1 min)

**Goal:** confirm the Mac is set up and the system is quiet enough for the benchmarks to be meaningful.

- Mac is signed into a user account (not stuck in setup flow).
- Connected to Wi-Fi.
- Plug in the charger — most tests want AC power.
- Note the date/time, store location, and serial number of the unit being tested.

**System quiet check** — background load skews the variance test. Confirm before Phase 4:

```bash
uptime                              # load averages
top -l 1 -n 5 -o cpu | tail -7      # top 5 CPU processes
```

The 1-minute load average should be well under the P-core count. The top-5 list should be near-zero CPU% for everything except WindowServer and `top` itself. If any non-system process is using > 5% CPU, close it before continuing — it will steal P-cores from the benchmark and produce iteration-to-iteration noise that looks like a bad-batch signature.

On a brand-new out-of-box Mac this is automatic. On a Mac that's been used for a while, kill: browsers, IDEs, Docker, Spotlight indexer (if mid-index), iCloud sync, Time Machine.

## Phase 1 — Hardware inventory (instant)

**Goal:** assert the unit matches the **target**.

```bash
./Verification/scripts/inventory.sh > Reports/<ts>-raw/inventory.json
```

Parse and check from the `summary` field — assertions come from the loaded target:

| Target field | Asserted against |
|---|---|
| `chip_pattern` | `summary.chip` (substring match) |
| `memory_gb` | `summary.memory_gb` (exact) |
| `model_must_include` | `summary.model` (substring) |

If the user opted out of a target, **skip assertions** and just record the actual values.

**Stop the run** if any assertion fails. Ask the user before continuing — they may be verifying a different SKU than they thought, or the wrong unit was handed to them.

Also record (informational, no assertion): perf_cores, efficiency_cores, SSD model + capacity, macOS version, serial number (will be hashed for the report).

## Phase 2 — Battery health (instant)

**Goal:** confirm a fresh, healthy battery.

```bash
./Verification/scripts/battery.sh > Reports/<ts>-raw/battery.json
```

Check:
- `cycle_count` ≤ 1
- `condition` == "Normal"
- `max_capacity_pct` ≥ 99
- `external_connected` and `is_charging` reasonable for context

A new unit should be 0 cycles or possibly 1 from factory testing. > 5 cycles is a strong signal it's a returned/refurb unit, regardless of the box's "new" label.

## Phase 3 — Sensor & port inventory (instant — uses Phase 1's output)

**Goal:** confirm all hardware advertised by the unit's own report is detected.

From the inventory JSON, confirm these are present:
- Built-in camera
- Built-in microphone
- Built-in speakers
- Wi-Fi module
- Bluetooth module
- Touch ID

Then check the unit-reports lines up with the form-factor expectations:
- MacBook Pro 14"/16": 3 × Thunderbolt, HDMI, SDXC, MagSafe
- MacBook Pro 14" base: as above but 2 × Thunderbolt
- MacBook Air: 2 × Thunderbolt, MagSafe (no HDMI/SDXC)
- Mac mini / Studio: varies — record what's reported, no specific count assertion

Anything advertised by Apple for that model but missing from the unit's report is a likely electrical / firmware issue. Surface to user.

## Phase 4 — CPU performance variance test (~10 min on Pro, ~6 min on Air)

**Goal:** detect batch-level performance variance / hot-spot throttling. **The headline test.** See the calibration's relevant note (e.g. [Performance Variance](../examples/m5-2026/Issues/Performance%20Variance.md) for the M5 generation) for the documented defect this test catches.

```bash
CHASSIS_CLASS=active-cooled-pro \
  ./Verification/scripts/cpu-variance.sh > Reports/<ts>-raw/variance.json
```

`CHASSIS_CLASS` defaults to `active-cooled-pro`. Valid values: `fanless` (Apple Silicon Air), `active-cooled-pro` (Apple Silicon MBP), `desktop` (Apple Silicon mini / Studio / iMac), `intel-laptop`, `intel-desktop`.

The test has three phases internal to the script:

1. **5 s cold burst** of parallel SHA-256 — captures peak boost throughput before the chassis heats up. Recorded as `burst_throughput_mb_per_s` for diagnostic comparison against the steady-state mean.
2. **Warmup** of continuous load — drives the chassis to thermal equilibrium so the timed iterations all measure steady-state behavior. Default depends on chassis:
	- `active-cooled-pro`: 300 s (16" MBP saturation is 5–8 min; 90 s would leave iteration 1 still riding the heating curve)
	- `fanless`: 60 s
	- `desktop` / `intel-laptop` / `intel-desktop`: 180 s
3. **5 × 60 s timed iterations** — measure aggregate throughput (MB/s) on the saturated chassis.

Total: ~10 min on Pro, ~6 min on Air, ~8 min on desktop / Intel. For a more thorough run:
`WARMUP_SEC=420 SECONDS_PER_ITER=90 ITERATIONS=5 ./Verification/scripts/cpu-variance.sh` (~15 min).

Why the long warmup matters: on a cold chassis, iteration 1 is necessarily faster than iteration 5 just because thermal mass is filling up — even a healthy unit. Warmup puts every iteration on the same thermal footing so the variance metrics measure *unit defect*, not test artifact.

> **Workload caveat.** SHA-256 is hardware-accelerated on Apple Silicon and Coffee Lake+ Intel. The test stresses thermal saturation and scheduling consistency — but not the integer pipelines or memory bandwidth that Cinebench would. Public reports of M5 Max bad batches came from Cinebench/Geekbench; this test catches *correlated* signals (variance + thermal behavior) but isn't 1:1 with their workload. A non-accelerated workload pass is on the [roadmap](../README.md#roadmap).

Check from the JSON:
- `spread_pct` ((max − min) / mean × 100) — pass < 5%, warn 5–10%, fail > 10%
- `max_to_min_ratio` — pass < 1.2×, warn 1.2–1.4×, fail ≥ 1.4× (catches single-iteration cliffs)
- `early_vs_late_decline_pct` — pass < 5%, warn 5–10%, fail > 10% (signature of a hot spot reaching threshold mid-test, which `spread_pct` can miss if decline is monotonic)
- `burst_to_steady_ratio` — *advisory only*. Recorded for comparison against the calibration baseline; the script does NOT change verdict from this. A ratio close to 1.0 on `active-cooled-pro` may indicate "always-throttled" but on `fanless` and `desktop` it's normal.
- A dead worker (any iteration's throughput == 0) is automatically a fail.
- The script automatically escalates **2 or more independent warn signals** to fail (compound-warn rule).

Any FAIL is **strongly suggestive of a batch-level defect**. Cross-reference the calibration's Performance Variance note in the report and recommend the user not accept this unit.

**Rerun-on-warn decision tree** (a single warn can be store-Wi-Fi background noise; act on the rerun):

| First run | Rerun action | Second run | Final |
|---|---|---|---|
| pass | none | — | pass |
| warn | rerun once | pass | pass *(note original warn in report)* |
| warn | rerun once | warn | **fail** *(compound evidence)* |
| warn | rerun once | fail | fail |
| fail | none | — | fail |

No third run — if two runs both warn, that's signal enough; running a third can mask thermal-paste defects that worsen with each iteration as the chassis stays saturated.

> No cooldown to Phase 5. The chassis ends Phase 4 hot — that's the right starting state for the sustained thermal test. Move directly into Phase 5.

## Phase 5 — Sustained thermal load (~10 min)

**Goal:** confirm the chassis can sustain the chip under prolonged load without thermal cliffs. Combined with Phase 4 this is ~16–20 min of continuous load (depending on chassis class) — past thermal saturation time on most chassis.

> Run directly after Phase 4 — chassis is already hot and that's the right starting state for sustained-load measurement.

Requires sudo for `powermetrics`. Prompt for sudo once:

```bash
sudo -v
sudo CHASSIS_CLASS=active-cooled-pro \
  ./Verification/scripts/thermal-load.sh > Reports/<ts>-raw/thermal.json
```

`CHASSIS_CLASS` selects the threshold table (matches the same env var as Phase 4). Default: `active-cooled-pro`. The inline `sudo CHASSIS_CLASS=...` form is preserved across the privilege boundary regardless of sudoers `env_keep` config.

Default: 10 minutes of continuous parallel hashing, with `powermetrics` sampling every 5 s (`smc` and `cpu_power` samplers). The script writes its own verdict per the chassis-class table in `thermal-load.sh` (mirrors [Pass-Fail Criteria](Pass-Fail%20Criteria.md)).

The script's `data_quality` field is the safety net: `no_samples` (sudo failed, format change, etc.) forces a `fail` verdict regardless of other metrics — so a misconfigured run can't false-pass.

Check from the JSON:
- `data_quality` == "ok" (or "few_samples" with verdict warn). `no_samples` is **fatal** — automatically forces fail.
- `cpu_die_temp_c.max` within the chassis-class threshold (see [Pass-Fail Criteria](Pass-Fail%20Criteria.md))
- `early_cliff_pct` (first 30 s) — the **textbook bad-batch signature** ("cliffs to base clock within 30 s") is now actually caught
- `frequency_cliff_pct` (mid-run, after 90 s warmup-skip) against chassis-class thresholds
- `steady_state_vs_peak_pct` against chassis-class thresholds
- `fan_rpm_avg.max - .min` ≥ 200 RPM (skip for fanless)
- `ambient_temp_c.first_sample` recorded from powermetrics — useful for cross-machine comparison (a unit tested in a 32°C store hits limits faster than one in a 21°C lab)
- The script automatically escalates **3 or more warn signals** to fail (compound-warn rule).

Frequency cliffs to base clock within 30 s under any chassis are the bad-batch / thermal-paste signature — `early_cliff_pct` catches this. Cross-reference the calibration's Performance Variance note for any cliff/steady fail.

## Phase 6 — Display visual inspection (~3 min)

**Goal:** find dead/stuck pixels, backlight bleed, color uniformity issues.

```bash
./Verification/scripts/display-test.sh
```

This opens an HTML page in the default browser. The agent prompts the user:

> Press **F** to fullscreen, **Space** to start cycling. ← / → to navigate manually. **Esc** exits fullscreen, **Cmd-W** closes the tab when done.

Walk through the colors with the user, asking for each:

| Color | Question to user |
|---|---|
| White | Any colored pixels (stuck), any black pixels (dead), any obvious patches/tint? |
| Red | Any non-red pixels? |
| Green | Any non-green pixels? |
| Blue | Any non-blue pixels? |
| 50% gray | Any obvious banding or patches? Some local-dimming structure is normal on mini-LED. |
| Black (dim ambient) | Any backlight bleed at edges/corners? Distinguish from IPS glow (glow shifts with viewing angle, bleed doesn't). |

Record yes/no per color. Severe issues → fail. Minor mini-LED blooming around bright transitions is normal on Pro displays — not a defect.

## Phase 7 — Manual physical inspection (~5 min)

**Goal:** find build quality issues invisible to software. The agent asks the user one question at a time and records the answer.

1. **Hinge creak.** Open and close the lid 3–4 times slowly. Open to ~110°. Press firmly on each palmrest corner. Twist the chassis gently. *Did you hear creaking?*

2. **Keyboard.** Open Notes or any text field. Type the alphabet, numbers, and modifier combos. *Any sticky, double-pressing, or non-responsive keys? Backlight uniform?*

3. **Trackpad.** Force-click each corner and the center. *All click uniformly with haptic feedback?*

4. **Touch ID.** System Settings → Touch ID & Password → enroll a finger. *Does enrollment succeed and unlock work?*

5. **Speakers.** Play a music clip with bass and treble at ~70% volume. *Any crackling, buzzing, or asymmetry between L and R?*

6. **Microphone.** QuickTime → New Audio Recording → speak. *Levels move? Playback clear?*

7. **Camera.** Open Photo Booth. *Live feed clean? Any banding / dead pixels in the sensor?*

8. **Ports.** If you have a USB-C drive / cable, plug it into each Thunderbolt port. *All mount and read?* Plug the charger into each port. *Charging LED responds in each?*

9. **MagSafe** (where applicable). Plug, unplug, plug. *LED state changes (amber → green)? Holds firmly but disengages cleanly?*

10. **HDMI / SDXC** (where applicable). Skip if no cable / card available. Otherwise test.

11. **Bluetooth.** Pair any device (AirPods, phone). *Connects?*

If any answer is "yes, there's an issue" the agent records it as a fail with severity per [Pass-Fail Criteria](Pass-Fail%20Criteria.md).

## Phase 8 — Apple Diagnostics (~5–10 min, includes reboot)

**Goal:** Apple's own hardware self-test.

> Before this phase, **write a partial JSON+MD report** to `Reports/<ts>.{json,md}` with progress so far, in case the session ends or the user closes the terminal during the reboot.

Prompt the user:

> Save your work. Reboot. As soon as the Mac powers off, **press and hold the power button** until "Loading startup options" appears. Release. Press **Cmd-D** (or follow the on-screen prompt for Diagnostics). Run the test.

When done, the user comes back to terminal and resumes the agent:

```bash
cd ~/mac-shakedown
# Claude Code:
claude continue   # or just `claude` and continue the conversation
# Other agents: re-invoke per your tool's resume convention
```

The user reports the result code(s) or "no issues found." Pass = all clear. Any reference code = fail; cross-reference Apple's [diagnostic codes](https://support.apple.com/en-us/102713) in the report.

## Phase 9 — Optional idle drain test (~30 min)

**Goal:** detect anomalous battery drain at idle.

Skip if time-constrained. Otherwise:

1. Charge to 100% and disconnect power.
2. Close the lid (sleep), or set display to never sleep and leave it idle on the lock screen.
3. Wait 30 minutes. Time it.
4. Wake. Note battery percentage:
   ```bash
   pmset -g batt
   ```

Pass: > 95% remaining (≤ 5% drain over 30 min sleep).
Warn: 90–95% remaining.
Fail: < 90% remaining.

## Phase 10 — Generate report

Two artifacts in `Reports/`:

1. **`Reports/<ISO-timestamp>.json`** — canonical, schema in [`Reports/SCHEMA.md`](../Reports/SCHEMA.md). Hashed serial. Submission-safe by default. *This is the artifact for the future hosted aggregator.*

2. **`Reports/<ISO-timestamp>.md`** — human-readable render of the JSON:
	- **Header:** timestamp, target, hashed serial, actual unit specs.
	- **Section per phase:** PASS/WARN/FAIL with concrete numbers and evidence.
	- **Summary table** of all checks.
	- **Final line:** `RESULT: PASS` or `RESULT: FAIL — <one-line reason>`.
	- **Recommendations:** for any FAIL or WARN, link the relevant calibration note and recommend action (return / accept / negotiate).

Per-phase raw script outputs are saved to `Reports/<ISO-timestamp>-raw/*.json` for evidence — the canonical JSON aggregates the verdicts but keeps these around for full auditability.
