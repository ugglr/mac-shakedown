# Changelog

All notable changes to this project are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The JSON report schema follows the versioning contract in [`Reports/SCHEMA.md`](Reports/SCHEMA.md): any change to the test methodology (runbook, thresholds, or scripts) bumps at least the patch version of the schema so submitted reports stay sortable across method revisions.

## [Unreleased]

### Added: in-store verification toolkit (wave 8)

- **`--store` thorough profile.** One flag for verifying a new unit (M5 especially): turns on `--noaccel` and `--gpu` and runs a longer warmup with more iterations, so an intermittent batch defect has more chances to surface. Honors any timing env vars the user set.
- **`compare-reports.sh`.** Diffs two reports side by side (a known-good sibling vs the unit under test) and flags every metric where the unit materially trails. Since the absolute thresholds aren't calibrated yet, this unit-to-unit comparison is the most trustworthy in-store signal.
- **Benchmark Reference** (`Verification/Benchmark Reference.md`). Install-this / run-this / expected-score guide with sourced, adversarially-verified Cinebench R24 + Geekbench 6 baselines per generation (M1-M5 families + Intel 2019), the in-store and hotel protocols, the Hong Kong return constraint, and live-lookup links (Geekbench Browser, mianibench.com crowd distributions). Corrected the stale M5 Max baseline in the m5-2026 calibration (~25-28k to ~29,000-29,400 GB6 multi-core).
- **Phase 12 STREAM triad.** Memory bandwidth now prefers a vendored single-file STREAM triad (`stream-triad.c`: real copy / scale / add / triad), compiled at runtime with clang, no network. Falls back to the pure-Python `memmove` proxy when clang is unavailable. Closes the copy-only-proxy gap; `details.method` records which ran.
- **Phase 14 `--llama` (opt-in).** Clones and builds llama.cpp at a pinned ref and runs `llama-bench`, a combined CPU+GPU+memory AI load (the workload class the M5 defect was reported on). Off by default; it reaches the network and runs third-party code (disclosed in SECURITY.md) and skips cleanly without git / cmake / network / model.
- **Schema 1.3.** Phase 12 gains the triad method and `*_triad_gb_per_s` fields; new phase key `14_llama_bench` (a `skipped` placeholder by default), added to the CI submission-audit required-phase list. Backward compatible: both phase-12 methods keep `mean_copy_gb_per_s`, and 14 is skipped unless opted in.

### Added: roadmap completion (wave 7)

- **Phase 4b non-accelerated CPU variance** (`cpu-variance.sh WORKLOAD=blake2b`, opt-in `./run --noaccel`). Reruns the Phase 4 variance methodology with BLAKE2b, which has no dedicated CPU instruction and so exercises the integer pipelines and memory instead of the SHA engine. Catches batch defects that SHA-NI / the Apple crypto coprocessor hide. Same script and verdict logic as Phase 4 (no duplicated thresholds): real `pass`/`warn`/`fail` when run, `skipped` placeholder otherwise. Runs on the already-hot chassis after Phase 4 with a short re-warm and no cold burst. Adds ~6 min when enabled.
- **Phase 12 memory bandwidth** (`memory-bandwidth.sh`). Multi-threaded sequential `ctypes.memmove` copy, one worker per P-core, over buffers sized to exceed the system-level cache (DRAM-bound, not cache-bound). Reports copy bandwidth, touched (read+write) bandwidth, and run-to-run spread. Pure Python stdlib with no native kernel, so it's an honest lower bound on a full STREAM triad (a single thread can't saturate Apple Silicon's multi-channel controllers, hence multi-threaded the way STREAM uses OpenMP). RAM-guarded: the working set is capped at 40% of physical memory, and it skips if it can't size cache-busting buffers. `info` verdict in v0.2. Runs cold, ~15 s.
- **Phase 13 GPU compute variance** (`gpu-variance.sh`, opt-in `./run --gpu`). Compiles a small Metal compute kernel with `swiftc` at runtime (no binary shipped) and runs sustained FMA work, measuring per-iteration GFLOP/s and variance. The GPU is the bigger thermal contributor on Apple Silicon. This is the one phase that isn't pure bash + Python stdlib; the Metal source is inline in the script heredoc. Degrades to `skipped` (never fails the run) when `swiftc`, the Metal compiler, or a Metal device is unavailable (headless / SSH session, or an Intel Mac without a usable GPU context). `info` verdict in v0.2. The default `./run` is unchanged and stays pure-script; see [SECURITY.md](SECURITY.md).
- **SSD conservative floor.** Phase 11 (`ssd-test.sh`) now emits `warn` (advisory, never fail) when read or write is below 500 MB/s with the page cache dropped, recorded as `ssd_floor_mb_per_s`. Every NVMe Mac since ~2016 clears > 1000 MB/s, so this flags the documented 256 GB single-NAND-die regression (M2 Air / base 13" MBP), a failing drive, or pre-NVMe storage. Calibrated chassis-family bands still land in v0.3.
- **14" vs 16" thermal sub-classes.** Split `active-cooled-pro` into `active-cooled-pro-14` (looser steady-state and cliff bands; the 14" M5 Max throttles by design) and `active-cooled-pro-16` (the previous strict thresholds). The bare `active-cooled-pro` stays valid as an alias for the 16" table, so existing presets and prior submissions stay comparable. Auto-detect can't distinguish 14" from 16" (system_profiler doesn't expose screen size on Apple Silicon), so the precise sub-class comes only from a `--target` preset; `mbp-14-m5-pro-24` and `mbp-16-m5-max-64` now set it explicitly.
- **Per-core pinning investigation** (`Verification/per-core-pinning.md`). Documents why macOS has no public per-core affinity API (`THREAD_AFFINITY_POLICY` is ignored on Apple Silicon, QoS only steers between the P and E clusters), why a single defective core gets averaged across workers, and why `worker_imbalance_pct_per_iter` is the chosen partial mitigation.
- **Generation calibrations: M1-M4 and Intel/T2 era.** Added `examples/m1-2020/`, `examples/m2-2022/`, `examples/m3-2023/`, `examples/m4-2024/`, and `examples/intel-2016/`, each a documented, sourced defect landscape in the `examples/m5-2026/` format (overview, per-issue notes, sources). Highlights: M1 24" iMac display-cable lines and 14"/16" speaker crackle; the M2 256 GB single-die SSD regression; M3's mostly-clean generation (8 GB RAM and M3 Pro bandwidth are spec choices, not defects); M4's OS-gated JIT kernel panic; and the Intel/T2 era's butterfly keyboard, Flexgate, T2 audio/panics, 2018 i9 throttling, and 2015 battery recall. Each issue maps to the Shakedown phase that surfaces it. Added representative target presets (`macbook-air-m1`, `macbook-air-m2`, `mbp-14-m3-pro`, `mac-mini-m4`) and repointed `mbp-16-intel-2019` at the new `examples/intel-2016/` calibration.
- **Schema bump to 1.2.** New phase keys (`12_memory_bandwidth`, `4b_cpu_variance_noaccel`, `13_gpu_variance`) added to the CI submission-audit required-phase list; the orchestrator always emits them (opt-in phases as `skipped` placeholders), so default-run submissions still pass. Backward compatible: pre-1.2 reports validate against the 1.1 shape.
- **Comparability impact.** The new `info` phases don't change existing verdicts. The SSD floor can turn a previously-`info` SSD result into `warn` (a PASS-with-warns) on genuinely slow drives. The `active-cooled-pro` → `-16` aliasing preserves prior thermal verdicts exactly; a 14" run with `--target mbp-14-...` is now judged against looser bands than before (it previously used the strict 16" table).

### Added: performance benchmarks (wave 6)

- **Phase 10 race benchmark (`race-bench.sh`).** Compresses a 200 MB incompressible random blob with `xz -9 -T<P-cores>` and reports wall-clock seconds plus MB/s throughput. Unlike Phase 4 (SHA-256, hardware-accelerated on Apple Silicon), LZMA is a general-purpose CPU workload that does not benefit from SHA-NI or Apple's crypto coprocessor, so the number is comparable across chassis families. Runs cold (before Phase 4) so boost headroom isn't already burned. Skipped gracefully if `xz` isn't on PATH.
- **Phase 11 SSD sequential read/write (`ssd-test.sh`).** Writes 2 GB of incompressible random data, drops the page cache via `sudo purge`, reads it back. Reports write_mb_per_s and read_mb_per_s. Uses `os.urandom`-generated random chunks since APFS transparently compresses zeros (a `dd if=/dev/zero` write would report fictional throughput). Free-space safety: skipped if less than 2× test size available. In `--no-sudo` mode the phase still runs with `ALLOW_NO_PURGE=1` but `page_cache_dropped: false` flags the read number as RAM-speed not SSD-speed.
- **Schema bump to 1.1.** New phases are additive. Backward compatible: pre-1.1 reports validate against the 1.0 shape. CI submission audit now requires the two new phase keys; legacy submissions need to be re-run on wave-6 to pass.
- **Race + SSD verdicts are `"info"` in v0.2.** No pass/fail thresholds yet (calibration corpus is empty). Numbers contribute to the corpus; v0.3 sets chassis-family thresholds once enough submissions accumulate.
- **Run time impact.** Adds ~1.5 min total. Phase 10 is 30-60 s depending on chassis; Phase 11 is ~10-15 s on Apple Silicon SSDs.

### Removed

- **`AGENTS.md` and `CLAUDE.md`**. The orchestrator (`./run`) handles all the automated phases end-to-end without an LLM, sudo and the y/N confirmation prompt mean an agent can't actually drive `./run` anyway, and the manual phases (display test, physical inspection, Apple Diagnostics, idle drain) are checklist work that a runbook covers directly. The cross-tool agent convention added churn without enabling anything. All agent framing dropped from README, Runbook, CONTRIBUTING, SECURITY, Reports/SCHEMA, targets/README, examples/m5-2026/README, Shakedown Brain, bug-report template, and cpu-variance.sh comments.

### Added: calibration submission workflow

- **`run-shakedown.sh` orchestrator.** Wraps the four auto-runnable phases (inventory, battery, CPU variance, thermal load) end-to-end, prompts sudo upfront, aggregates into a SCHEMA-compliant JSON, and emits a sanitized submission copy alongside the full local copy. One command instead of five-plus, with the predictable `{YYYY-MM-DD}-{preset}-{hash4}.json` filename convention.
- **`--target` is optional.** Running without a preset auto-detects chassis class from `system_profiler` (override with `CHASSIS_CLASS` env var), skips inventory asserts, and softens the battery "factory-fresh" checks (cycle count, ≥99% capacity) since those only make sense on a new-purchase verification. Real-degradation checks still apply. Filename becomes `{YYYY-MM-DD}-{chassis}-{memory}gb-{hash4}.json`.
- **`./run` convenience entry.** Thin shim at the repo root, execs the orchestrator with all args forwarded. Means the public command is `./run` after `cd ~/mac-shakedown`, not the longer `./Verification/scripts/run-shakedown.sh`.
- **`--no-sudo` (alias `--skip-thermal`).** Skips Phase 5, the only phase that needs sudo. Phase 4 (variance) still runs and is the headline test. Half the runtime, no password.
- **Sudo keep-alive.** Background loop refreshes `sudo -n true` every 60 s while the orchestrator runs. macOS default sudo timestamp is 5 min and Phase 4 on Intel takes ~8 min, so the user would otherwise hit a second password prompt mid-run.
- **Flame banner.** Colored ASCII banner on startup, suppressed when stderr isn't a TTY (CI / piped output stays clean).
- **`Reports/local/` vs `Reports/submissions/` split.** Full output with `_raw_*` debug fields stays gitignored; sanitized copy is committable as a PR. Plaintext serials never reach the submission copy, even with `INCLUDE_PLAINTEXT_SERIAL=1`.
- **CI submission audit.** New step in `.github/workflows/lint.yml` triggered on PRs touching `Reports/submissions/**`. Rejects any `_raw_*` field, `raw_log_path`, plaintext `serial_number`, off-pattern filename, missing SCHEMA fields, or `submission_safe != true`.
- **README "Submit a calibration report" section**, plus CONTRIBUTING.md submission flow and a PR-template checkbox for calibration submissions. Until a hosted aggregator exists, PRs are how the calibration corpus grows.
- **Soft inventory assert for `model_must_include`.** Apple Silicon's `machine_model` (e.g. `Mac17,1`) doesn't reliably contain the screen-size substring, so a mismatch now warns rather than fails. Chip and memory remain hard asserts (those are reliable from `system_profiler`).

### Added: methodology hardening

- **Phase 4 cold burst measurement.** First 5 s of parallel SHA-256 captured before warmup heats the chassis. Burst figure recorded as `burst_throughput_mb_per_s` for diagnostic comparison against the steady-state mean (advisory; doesn't drive verdict without a calibration baseline).
- **Phase 4 chassis-class-aware warmup defaults.** `active-cooled-pro` now defaults to **300 s** (was 90 s; a 16" MBP needs 5–8 min to reach thermal saturation). `fanless` defaults to 60 s, `desktop` / `intel-laptop` / `intel-desktop` default to 180 s. Total Phase 4 runtime: ~10 min on Pro, ~6 min on Air.
- **`max_to_min_ratio` warn band 1.2–1.4×.** Was previously fail-only at ≥ 1.4×; the warn band catches near-miss units.
- **Phase 4 dead-worker safeguard.** Any iteration with zero throughput now forces fail (was previously masked by `min(throughputs) > 0 else 1.0` fallback that produced ratio = 1.0 → silent PASS).
- **Phase 4 worker-imbalance reporting.** Within-iter `(max_worker - min_worker) / max_worker × 100` recorded per iteration, so a defective single core is at least visible in the JSON even if the macOS scheduler routes around it.
- **Phase 5 early-window cliff metric.** First 30 s frequency cliff now evaluated separately from the post-warmup mid-run cliff. The textbook bad-batch signature ("cliffs to base clock within 30 s under load") was previously thrown away by the 90 s warmup-skip; it's now `early_cliff_pct` with chassis-class thresholds.
- **Phase 5 ambient-temp capture.** `powermetrics` Ambient/Battery temp readings recorded as `ambient_temp_c.first_sample` and `.max_during_run`, useful for cross-machine comparison (a Mac tested in a 32 °C store hits limits faster than one in a 21 °C lab).
- **Phase 5 chassis-class-aware verdicts.** Script previously hardcoded `active-cooled-pro` thresholds, which would false-fail an Air or false-pass a desktop. Now reads `CHASSIS_CLASS` env var (default `active-cooled-pro`) and applies the correct threshold table.
- **Phase 5 multi-fan regex.** Handles `Fans:` headers and per-fan lines on 16" MBP and Mac Studio (previously matched only `Fan:` and `Fan N:`, leaving fan_avgs empty on multi-fan chassis).
- **Phase 5 data-quality safety net.** `data_quality: "no_samples"` automatically forces fail. Previously the verdict logic could short-circuit on empty lists and emit a misleading PASS with no reasons when sudo failed or powermetrics output format changed.
- **Compound-warn escalation.** Phase 4 escalates 2+ warn signals to fail; Phase 5 escalates 3+. Multiple simultaneous near-threshold readings shouldn't aggregate to a single warn.
- **Process-group kill in Phase 5.** `thermal-load.sh` now backgrounds the load in its own process group and `kill -- -$LOAD_PGID`s on EXIT/INT/TERM. Previously `kill $LOAD_PID` only signalled the parent Python and orphaned the multiprocessing pool.
- **Hashed serial numbers actually happen.** `inventory.sh` and `battery.sh` now hash serial numbers with SHA-256 by default and emit `serial_hash` (the README claimed this; the implementation now matches the claim). Plaintext serial is opt-in via `INCLUDE_PLAINTEXT_SERIAL=1`.
- **Privacy-aware inventory output.** Full `system_profiler` and `ioreg` dumps moved into `_raw_*` fields with comments explaining they may contain paired Bluetooth IDs, Wi-Fi SSIDs, USB device serials, etc. The orchestrator strips these from the canonical submission JSON.

### Added: Intel and older Apple Silicon support

- **`intel-laptop` and `intel-desktop` chassis classes** with looser thermal thresholds reflecting Intel's aggressive throttling (steady-state ≥ 50% of peak rather than ≥ 70%).
- **Intel powermetrics format.** `thermal-load.sh` now also parses `CPU N frequency:`, `Package Power:`, `IA Cores Power:`, `GT Cores Power:` so frequency and power summaries populate on Intel.
- **`mbp-16-intel-2019.json`** target preset as a worked example.
- **`inventory.sh` Intel chip detection** falls back to `cpu_type` when `chip_type` is absent (Apple Silicon vs. Intel `system_profiler` keys differ); records `is_apple_silicon` flag for downstream reasoning.
- Generation coverage table in `targets/README.md`: M5 (primary), M1–M4 (scripts work, no per-generation calibration yet), Intel 2018+ (works with new chassis classes), pre-2018 (untested).

### Added: OSS hygiene

- `CHANGELOG.md` (this file).
- `SECURITY.md` covering surface-area summary, the only `sudo` use (`powermetrics`), private security advisory pointer.
- `.github/ISSUE_TEMPLATE/{defect-report,bug-report,config}.yml` form-style templates with PII-review checklist tied to `submission_safe`/`store_location`/etc.
- `.github/pull_request_template.md` type-of-change checklist plus validation requirements (run affected scripts, paste JSON, note chip/RAM).
- `.github/workflows/lint.yml` runs shellcheck on every script, `python3 -m json.tool` on every target preset, `ast.parse` on every Python heredoc, plus a markdown-link existence check.
- `examples/sample-report-illustrative/` hand-crafted example PASS run on a 16" M5 Max 64 GB so visitors can see what the harness produces without running it themselves.
- README "Status (v0.1)" callout disclosing the methodology has not yet been validated against a confirmed-defective unit.
- README "Supported agents" table with verification status per agent (Claude Code ✅, others 🟡 unverified). (Removed in this release; see above.)
- README Quick start broken into numbered steps so the `xcode-select --install` 5–10 min wait is no longer hidden in a comment.

### Changed

- `examples/m5-max-2026/` renamed to `examples/m5-2026/`. The calibration covers M5 / M5 Pro / M5 Max, and the Air target preset reuses the same calibration directory.
- `Verification/Pass-Fail Criteria.md` rewritten with chassis-class threshold tables, compound-warn escalation, the `burst_to_steady_ratio` advisory note, and the SHA-256 workload caveat.
- README total runtime claim updated: ~45 min on MBP, ~25 min on Air, ~35 min on desktop / Intel (was a flat ~40 min).
- `AGENTS.md` operating principles expanded to cover `CHASSIS_CLASS` pass-through, rerun-on-warn discipline, and trust-the-data_quality-field guidance. (Then removed entirely in this release.)
- **Recommended sudo invocation switched from `sudo -E ./thermal-load.sh` to inline `sudo CHASSIS_CLASS="$CHASSIS_CLASS" ./thermal-load.sh`** across README, AGENTS.md, and Runbook. The `-E` form silently dropped `CHASSIS_CLASS` on default macOS sudoers configs (`env_keep` doesn't list it, admin rules don't grant `SETENV`), falling back to `active-cooled-pro` defaults: wrong thresholds for fanless, desktop, and Intel chassis. The inline form is preserved regardless of sudoers `env_keep`.
- **Markdown-link CI check rewritten in Python** (`.github/workflows/lint.yml`). The previous bash version used `${path//%/\\x}` URL decoding that works in bash (so CI on `ubuntu-latest` is fine) but produces false positives in zsh. Contributors running the check locally on default-shell macOS hit broken-link errors on any path with `%`-encoded characters.
- Drain framing reconciled across Runbook + Pass-Fail Criteria. Both `% remaining` and `% drain` documented for the 30-min idle test.

### Fixed

- **`display-test.sh` Esc handler** now exits fullscreen. Previously called `window.close()`, which silently fails on tabs the user navigated to (rather than ones opened by JS): the script claimed Esc would exit but it didn't. The page now also documents `Cmd-W` for closing the tab.
- **`display-test.sh` tempfile handling.** The previous `HTML=$(mktemp -t shakedown-display).html` orphaned a 0-byte mktemp file because BSD `mktemp -t` treats its argument as a literal prefix (the X-template expansion is GNU-only). Now uses `mktemp -d` for a unique directory and a fixed `page.html` inside, so the `.html` extension is preserved for `open`'s Safari dispatch.
- **`display-test.sh` validates `SECONDS_PER_COLOR`** as a positive integer before sed-injecting into the page's JavaScript. Previously a non-numeric value produced broken JS or, in adversarial use, JS injection in the local browser tab.

### Known limitations (calibration baseline pending)

- The methodology has not yet been validated against a confirmed-defective unit. Thresholds are derived from public reports and a small number of presumed-good runs.
- Phase 4 uses SHA-256 which is hardware-accelerated on Apple Silicon and Coffee Lake+ Intel. It stresses the SHA engines, scheduling, and thermal mass, but not the integer pipelines or memory bandwidth that Cinebench / Geekbench probe more thoroughly. The variance methodology transfers cleanly to any sustained workload; the SHA choice is for zero-install portability. A non-accelerated workload pass is on the roadmap.
- GPU not yet covered. Memory bandwidth not yet covered.
- NVMe SSD sequential read/write covered as of wave 6 (Phase 11), but the numbers are informational only in v0.2; chassis-family thresholds land in v0.3.
- 14" and 16" MBP currently share the `active-cooled-pro` threshold table. The calibration's [Thermal Throttling note](examples/m5-2026/Issues/Thermal%20Throttling.md) describes 14" M5 Max throttling as design behavior, so a working 14" may land in the warn band of the current thresholds. A separate 14" sub-class is on the roadmap.

## [0.1.0] 2026-04-30

### Added

- Initial release.
- Verification machinery (generation-agnostic): runbook, pass/fail criteria parameterized by chassis class, and the five core scripts: `inventory.sh`, `battery.sh`, `cpu-variance.sh`, `thermal-load.sh`, `display-test.sh`.
- Phase 0–9 procedure: pre-flight, hardware identity, battery health, sensor inventory, CPU variance (90 s warmup + 5 × 60 s timed iterations, parallel SHA-256), 10-minute sustained thermal load with `powermetrics` sampling, fullscreen display visual inspection, manual physical inspection, Apple Diagnostics, and an optional 30-minute idle-drain test.
- Target presets: `mbp-16-m5-max-64`, `mbp-14-m5-pro-24`, `macbook-air-m5-16`.
- M5 (2026) generation calibration under `examples/m5-max-2026/` (renamed in [Unreleased]).
- `AGENTS.md` cross-tool agent operating manual, with `CLAUDE.md` as the Claude Code auto-loader pointer. (Both removed in [Unreleased].)
- JSON report schema v1.0 with hashed-serial design, submission-safety flag, and opt-in fields for future crowd-sourced aggregation.

[Unreleased]: https://github.com/ugglr/mac-shakedown/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ugglr/mac-shakedown/releases/tag/v0.1.0
