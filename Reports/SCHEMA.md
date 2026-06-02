# Report Schema

Every QA run produces two artifacts in `Reports/`:

- **`<ISO-timestamp>.json`**: canonical machine-readable report. Stable, versioned schema. *This is what gets submitted to the future aggregator.*
- **`<ISO-timestamp>.md`**: human-readable render of the JSON.

## Top-level fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema_version` | string | yes | Semver of the schema. Currently `"1.2"`. |
| `shakedown_version` | string | yes | Tool version that produced the report (e.g. `"0.1.0"`). |
| `timestamp` | string | yes | ISO 8601 UTC. |
| `illustrative` | bool | no | `true` for hand-crafted samples (under `examples/sample-report-*`). Aggregator must filter these out. |
| `illustrative_note` | string | no | Companion to `illustrative: true`. |
| `target` | object | yes | The target preset / spec the run asserted against. See [target presets](../targets/README.md). |
| `unit` | object | yes | The actual unit's hardware identity (collected by `inventory.sh`). |
| `phases` | object | yes | One key per phase (see Phase shape). |
| `result` | string | yes | `"PASS"` / `"FAIL"`. |
| `result_reason` | string | yes | One-line summary. |
| `submission_safe` | bool | yes | Orchestrator's assertion that no PII is present. |
| `store_location` | string\|null | no | Opt-in only. |
| `purchase_date` | string\|null | no | Opt-in only. |

## `unit` object: cross-machine comparison

This is what the aggregator groups on for per-SKU baselines.

| Field | Type | Notes |
|---|---|---|
| `model` | string | e.g. `"MacBook Pro"` |
| `model_identifier` | string | e.g. `"Mac17,1"` |
| `chip` | string | e.g. `"Apple M5 Max"` (Apple Silicon) or `"Intel Core i7"` (Intel) |
| `is_apple_silicon` | bool | true if `chip_type` was reported by `system_profiler` |
| `perf_cores` | int | P-cores on Apple Silicon, all physical cores on Intel |
| `efficiency_cores` | int | E-cores on Apple Silicon, 0 on Intel |
| `logical_cpus` | int | Includes hyperthreading on Intel |
| `memory_gb` | int | rounded |
| `storage_gb` | int | total NVMe capacity (informational) |
| `macos_version` | string | e.g. `"macOS 16.3 (Tahoe)"` |
| `kernel_version` | string | e.g. `"Darwin 26.3.0"` |
| `serial_hash` | string | `"sha256:<hex>"`, hashed by `inventory.sh`. See "Hash caveat" under Privacy below. |
| `serial_number` | string | **only present** if user set `INCLUDE_PLAINTEXT_SERIAL=1`. When present, `./run` sets `submission_safe: false` on the local copy and refuses to write the submission copy. |
| `power_adapter` | object\|null | `{name, wattage, connected, charging}` from SPPowerDataType, relevant for sustained-perf headroom. |

## Each phase's shape

Every entry in `phases` follows the same shape:

```json
"<n>_<name>": {
  "verdict": "pass" | "warn" | "fail" | "skipped",
  "duration_s": <int>,
  "details": { …phase-specific… },
  "verdict_reasons": ["<short string>", ...]
}
```

`verdict_reasons` lists every fail and warn signal that fired, plus advisory info. Empty / single-entry "within healthy range" line on a clean PASS.

## Phase 4 (`4_cpu_variance`): full detail

Produced by `cpu-variance.sh`. Comparable across submissions when grouped by `unit.chip` + `unit.memory_gb` + `unit.perf_cores`.

```json
{
  "verdict": "pass",
  "duration_s": 605,
  "details": {
    "chassis_class": "active-cooled-pro",
    "burst_sec": 5,
    "warmup_sec": 300,
    "iterations": 5,
    "seconds_per_iter": 60,
    "workers": 12,
    "burst_throughput_mb_per_s": 28640.2,
    "warmup_tail_throughput_mb_per_s": 23110.5,
    "throughput_mb_per_s": [23080.3, 23142.1, 23071.9, 23105.4, 23048.7],
    "min_mb_per_s": 23048.7,
    "max_mb_per_s": 23142.1,
    "mean_mb_per_s": 23089.7,
    "stdev_mb_per_s": 36.4,
    "spread_pct": 0.405,
    "max_to_min_ratio": 1.004,
    "early_vs_late_decline_pct": 0.213,
    "burst_to_steady_ratio": 0.806,
    "worker_imbalance_pct_per_iter": [0.4, 0.6, 0.3, 0.5, 0.4],
    "median_worker_imbalance_pct": 0.4,
    "max_worker_imbalance_pct": 0.6,
    "workload": "sha256-parallel (hardware-accelerated on Apple Silicon; see script header CAVEAT)"
  },
  "verdict_reasons": [
    "spread 0.41%, ratio 1.00×, decline 0.21%, within healthy range"
  ]
}
```

## Phase 5 (`5_thermal_load`): full detail

Produced by `thermal-load.sh`. Includes ambient temp for cross-machine comparison.

```json
{
  "verdict": "pass",
  "duration_s": 600,
  "details": {
    "chassis_class": "active-cooled-pro",
    "sample_interval_s": 5,
    "workers": 12,
    "samples_captured": 120,
    "data_quality": "ok",
    "data_quality_notes": [],
    "powermetrics_rc": 0,
    "ambient_temp_c": { "first_sample": 22.3, "max_during_run": 24.1 },
    "cpu_die_temp_c": { "n": 120, "min": 64.2, "max": 94.8, "mean": 89.3, "first": 64.2, "last": 91.7 },
    "gpu_die_temp_c": { "n": 120, "min": 38.1, "max": 52.4, "mean": 47.8, "first": 38.1, "last": 49.6 },
    "fan_rpm_avg":    { "n": 120, "min": 1840, "max": 5840, "mean": 5510, "first": 1840, "last": 5780 },
    "p_cluster_freq_mhz": { "n": 120, "min": 3540, "max": 4280, "mean": 3892, "first": 4280, "last": 3580 },
    "combined_power_w": { "n": 120, "min": 8.4, "max": 64.2, "mean": 58.7, "first": 8.4, "last": 60.3 },
    "early_cliff_pct": 6.8,
    "frequency_cliff_pct": 8.1,
    "steady_state_vs_peak_pct": 84.3,
    "thresholds_used": { "cpu_temp_warn": 100, "cpu_temp_fail": 105, "steady_warn": 70, "steady_fail": 60, "cliff_warn": 20, "cliff_fail": 30, "early_cliff_warn": 25, "early_cliff_fail": 40, "expect_fan_ramp": true },
    "raw_log_path": "/var/folders/.../shakedown-pm.AbC123",
    "intel_cpu_freq_mhz": null,
    "intel_package_power_mw": null,
    "intel_ia_cores_power_mw": null,
    "intel_gt_cores_power_mw": null
  },
  "verdict_reasons": ["all thresholds passed (active-cooled-pro)"]
}
```

The `intel_*` fields are populated only on Intel Macs (where the chassis class is `intel-laptop` or `intel-desktop`); on Apple Silicon they're `null`. Conversely `p_cluster_freq_mhz` / `combined_power_w` are populated on Apple Silicon and `null` on Intel.

`raw_log_path` points at a per-user tempfile under `/var/folders/...`. `./run` strips it from the canonical submission JSON.

## Phase 10 (`10_race_bench`): full detail

Produced by `race-bench.sh`. Fixed-work CPU race: compresses a 200 MB incompressible random blob with `xz -9 -T<P-cores>`. Unlike Phase 4 (SHA-256, hardware-accelerated on Apple Silicon), this workload is a fair cross-chassis-family comparison since LZMA does not benefit from SHA-NI or the Apple crypto coprocessor.

```json
{
  "verdict": "info",
  "duration_s": 42,
  "details": {
    "workload": "xz -9 -T12 compression of 200MB random data",
    "blob_size_mb": 200,
    "threads": 12,
    "preset": 9,
    "wall_seconds": 42.317,
    "input_bytes": 209715200,
    "output_bytes": 209665024,
    "compression_ratio": 0.9998,
    "throughput_mb_per_s": 4.73,
    "data_quality": "ok",
    "data_quality_notes": []
  },
  "verdict_reasons": [
    "compressed 200MB in 42.32s (4.7 MB/s, output 100.0% of input)",
    "informational in v0.2; calibrated pass/fail thresholds land in v0.3"
  ]
}
```

Race numbers are informational in v0.2: there are no chassis-family thresholds yet. Once submissions populate a baseline corpus, v0.3 sets pass/fail bands per chassis family.

`verdict: "skipped"` if `xz` is not on PATH (pre-Catalina) or `xz` returned a non-zero exit code.

## Phase 11 (`11_ssd_test`): full detail

Produced by `ssd-test.sh`. Sequential write+read benchmark on incompressible random data, with page cache dropped (`sudo purge`) between write and read.

```json
{
  "verdict": "info",
  "duration_s": 8,
  "details": {
    "workload": "sequential write+read of 2GB incompressible random data",
    "size_gb": 2,
    "chunk_mb": 8,
    "write_seconds": 4.213,
    "write_mb_per_s": 485.7,
    "page_cache_dropped": true,
    "read_seconds": 3.892,
    "read_mb_per_s": 525.8,
    "data_quality": "ok",
    "data_quality_notes": []
  },
  "verdict_reasons": [
    "write 486 MB/s, read 526 MB/s",
    "informational in v0.2; calibrated pass/fail thresholds land in v0.3"
  ]
}
```

Why incompressible random data: APFS transparently compresses zero-blocks, so `dd if=/dev/zero` writes report fictional throughput (the OS never touches the SSD for compressible sections). The script generates one 8 MB random chunk via `os.urandom` and writes it repeatedly.

Why `sudo purge` between write and read: without dropping the page cache, the read measures RAM bandwidth (~10–50 GB/s on modern Macs), not SSD. In `--no-sudo` mode, the phase still runs but `page_cache_dropped: false` and `data_quality: "few_samples"` flag the inflated read number.

`verdict: "skipped"` if free disk space is less than 2× the test size.

As of schema 1.2 the phase carries a conservative warn-only floor (`ssd_floor_mb_per_s`, default 500). When the page cache was actually dropped and read or write falls below it, the verdict becomes `"warn"` with an advisory reason. Every NVMe-equipped Mac since ~2016 clears well over 1000 MB/s sequential, so a number this low points at a real problem (the documented 256 GB single-NAND-die regression on the M2 Air and base 13" MBP, a failing drive, or pre-NVMe SATA/Fusion storage). It is a floor, not a calibrated band: chassis-family pass/fail thresholds still land in v0.3.

## Phase 12 (`12_memory_bandwidth`): full detail

Produced by `memory-bandwidth.sh`. Multi-threaded sequential `ctypes.memmove` copy, one worker per P-core, over buffers sized to exceed the system-level cache so it measures DRAM bandwidth, not cache. Comparable across submissions grouped by `unit.chip` + `unit.memory_gb`.

```json
{
  "verdict": "info",
  "duration_s": 10,
  "details": {
    "workload": "multi-threaded sequential memcpy (ctypes.memmove), DRAM-bound",
    "workers": 12,
    "per_buffer_mb": 64,
    "total_working_set_mb": 1536,
    "iterations": 5,
    "seconds_per_iter": 2,
    "copy_bandwidth_gb_per_s": [98.2, 97.8, 98.5, 98.1, 97.9],
    "mean_copy_gb_per_s": 98.1,
    "min_copy_gb_per_s": 97.8,
    "max_copy_gb_per_s": 98.5,
    "spread_pct": 0.71,
    "touched_bandwidth_gb_per_s_mean": 196.2,
    "wall_seconds": 10.4,
    "data_quality": "ok",
    "data_quality_notes": []
  },
  "verdict_reasons": [
    "mean copy 98.1 GB/s (read+write ~196.2 GB/s touched) across 12 workers, spread 0.7%",
    "informational in v0.2; calibrated pass/fail thresholds land in v0.3"
  ]
}
```

`copy_bandwidth_gb_per_s` counts bytes copied (N per `memmove`). Each copy also reads N and writes N, so `touched_bandwidth_gb_per_s_mean` (2x the copy mean) is the read+write traffic the controller actually moved. This is a lower bound on a full STREAM triad: scale / add / triad need elementwise arithmetic that pure Python can't do at memory speed without a native kernel. `memmove` is the honest stdlib proxy, and it still catches a memory subsystem that is slow or inconsistent across runs. A single thread cannot saturate the multi-channel controllers on Apple Silicon, so the test is multi-threaded the way STREAM is built with OpenMP.

`verdict: "skipped"` when there is not enough RAM to size cache-busting buffers for the worker count (the working set is capped at 40% of physical memory).

## Phase 4b (`4b_cpu_variance_noaccel`): full detail

Produced by `cpu-variance.sh` with `WORKLOAD=blake2b`: the same script, the same verdict logic, a different workload. BLAKE2b has no dedicated CPU instruction, so it runs on the integer pipelines instead of the SHA engine and catches batch defects that SHA-NI / the Apple crypto coprocessor would hide. Opt-in (`./run --noaccel`).

The `details` shape is identical to Phase 4 (`4_cpu_variance`), with `workload` set to the BLAKE2b string. When it runs it emits a real `pass` / `warn` / `fail` verdict against the same chassis-agnostic variance thresholds (variance is a within-unit consistency measure, so the thresholds transfer across workloads). The orchestrator runs it right after Phase 4 on the already-hot chassis, with a short re-warm and no cold burst.

`verdict: "skipped"` when `--noaccel` is not passed.

## Phase 13 (`13_gpu_variance`): full detail

Produced by `gpu-variance.sh`. Opt-in (`./run --gpu`). Compiles a small Metal compute kernel with `swiftc` at runtime (no binary is shipped in the repo) and runs sustained FMA work, measuring per-iteration GFLOP/s the same way the CPU variance test measures throughput. The GPU is the bigger thermal contributor on Apple Silicon, so this surfaces GPU-side batch variance the CPU phases miss.

```json
{
  "verdict": "info",
  "duration_s": 16,
  "details": {
    "workload": "metal-compute fma burn (GPU sustained FP throughput variance)",
    "device": "Apple M5 Max",
    "low_power": false,
    "iterations": 5,
    "seconds_per_iter": 3,
    "threads_per_dispatch": 1048576,
    "fma_iters_per_thread": 4096,
    "throughput_gflops": [8120.4, 8104.9, 8118.2, 8099.7, 8110.1],
    "mean_gflops": 8110.7,
    "min_gflops": 8099.7,
    "max_gflops": 8120.4,
    "spread_pct": 0.256,
    "max_to_min_ratio": 1.003,
    "early_vs_late_decline_pct": 0.12,
    "wall_seconds": 16,
    "data_quality": "ok",
    "data_quality_notes": []
  },
  "verdict_reasons": [
    "Apple M5 Max: mean 8111 GFLOP/s, spread 0.3%, ratio 1.00x",
    "informational in v0.2; GPU variance thresholds land once the corpus has baselines"
  ]
}
```

This is the one phase that is not pure bash + Python stdlib: a real GPU load needs a GPU kernel. The Metal source lives in the `gpu-variance.sh` heredoc; read it before running. The phase degrades to `verdict: "skipped"` (it never fails the run) when `swiftc` is absent, the Metal source fails to compile, or no Metal device is available (headless / SSH session, or an Intel Mac without a usable GPU context). See [SECURITY.md](../SECURITY.md) for the opt-in-compile disclosure.

`verdict: "skipped"` when `--gpu` is not passed, or when the GPU / toolchain is unavailable.

## Note on phase key ordering

The phase keys (`0_preflight`, `1_inventory`, ... `4b_cpu_variance_noaccel`, `10_race_bench`, `12_memory_bandwidth`, `13_gpu_variance`) sort alphabetically rather than numerically (`10` comes before `2` lexicographically, and `4b` sorts after `4`). JSON output preserves the orchestrator's insertion order so human-readable reports render in run order: preflight, inventory, battery, sensors, race, ssd, memory_bandwidth, cpu_variance, cpu_variance_noaccel, thermal_load, gpu_variance, then the skipped manual phases. Parsers iterating phase names should not assume numeric sort order.

## Privacy / submission-safety

Reports default to submission-safe:
- **Serial number is hashed** (SHA-256) by `inventory.sh` and `battery.sh`. The plaintext serial is **not** stored unless `INCLUDE_PLAINTEXT_SERIAL=1` is set; when set, `./run` keeps the plaintext in the local copy only and strips it from the submission copy.
- **`store_location`, `purchase_date`** are `null` by default. Opt in to enable batch-correlation (e.g. "all units bought at HK Apple Causeway Bay in April 2026 with this defect").
- **`_raw_*` fields** in the inventory and battery sub-blocks contain the full `system_profiler` / `ioreg` dumps and may include paired Bluetooth device IDs, Wi-Fi SSIDs, USB device serials, etc. `./run` strips these from the submission copy and keeps them only in the local `Reports/local/*.json`. **`submission_safe: true`** asserts they're stripped.
- **`submission_safe: true`** is the orchestrator's assertion that no PII has snuck in. If the user passes `--notes "…"`, the orchestrator flips this to `false` since notes may contain identifying info.

### Hash caveat: obfuscation, not anonymization

The `serial_hash` is SHA-256 of the plaintext serial **without a salt**. Apple's serial number space has limited entropy (post-2010 format: ~3 chars location/year/week + ~4 chars unique + ~4 chars model = roughly 10⁸ realistic combinations per chassis SKU). A determined aggregator with the report's `unit.model_identifier` and `unit.chip` can rainbow-table the original serial in seconds.

The hash is genuinely useful for **deduplication**: the aggregator can detect repeat submissions of the same unit without storing serials. It is **not** anonymization. Treat `submission_safe: true` as "no plaintext PII," not "untraceable."

A future hosted aggregator should rotate to HMAC-SHA-256 with a per-deployment secret, so the aggregator-side dedup works but external attackers can't recover the serial. Until that lands, the threat model is: aggregator operator can recover serials; everyone else can't.

## Versioning policy

- **Patch bumps (1.0.0 → 1.0.1)** add optional fields. Old aggregators read the new reports fine.
- **Minor bumps (1.0 → 1.1)** can change non-critical structure. Aggregator handles both.
- **Major bumps (1.0 → 2.0)** are breaking. Aggregator must explicitly support each major version.

If a test methodology changes (e.g. variance test gains a new metric, or thresholds shift), bump at least the patch version and document the change in [CHANGELOG.md](../CHANGELOG.md). Methodology changes that affect comparability across submissions should bump the minor or major.

### History

- **1.0** → initial release schema (phases 0-9).
- **1.1** → added phases 10_race_bench and 11_ssd_test (informational; pass/fail thresholds pending v0.3 calibration corpus). Backward compatible: reports without these phases still validate as 1.0 shape.
- **1.2** → added phases 12_memory_bandwidth (informational), 4b_cpu_variance_noaccel (opt-in non-accelerated variance, real pass/warn/fail when run), and 13_gpu_variance (opt-in Metal compute, informational). Added a conservative warn-only floor to 11_ssd_test (`ssd_floor_mb_per_s`) and split the `active-cooled-pro` thermal class into `active-cooled-pro-14` / `active-cooled-pro-16` (the bare class stays valid as the 16"-equivalent, so older reports and presets still compare). Backward compatible: 4b and 13 are `skipped` placeholders unless opted in.
