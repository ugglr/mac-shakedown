# Security

Shakedown runs entirely on the user's own Mac. The surface area is small: a handful of short shell scripts plus inline Python heredocs, no external dependencies beyond what ships with macOS, no outbound network calls, and no daemons or persistent components. Everything is local. Auditing the scripts before running them is encouraged. They are pure bash and Python, no minified or obfuscated code, and short enough to read end to end in a few minutes. One exception, opt-in only: the `--gpu` phase compiles a small Metal kernel at runtime (see below).

## What the scripts do with elevated privileges

- `Verification/scripts/thermal-load.sh` invokes `sudo powermetrics` for read-only thermal, CPU-frequency, and ambient-temp sampling. This is the **only** script that requires elevation, and `powermetrics` is the only command run under `sudo`.
- No other script asks for, requires, or uses elevated privileges.
- All other data collection is unprivileged: SHA-256 over a fixed in-memory 1 MB buffer for the CPU workload (deterministic; no I/O), hardware facts via `system_profiler` / `ioreg` / `sysctl`, and battery state via `ioreg AppleSmartBattery`.
- Writes are confined to the repo's `Reports/` directory and short-lived tempfiles under `/var/folders/.../shakedown-*` (the system per-user temp area). Nothing is written elsewhere.
- No outbound network requests are made by any script. Reports stay on the local disk unless the user chooses to share them.

## Optional GPU phase (`--gpu`)

The default `./run` is pure bash plus Python stdlib and ships no compiled binaries. The opt-in `--gpu` phase is the one exception: a real GPU load needs a GPU kernel, so `gpu-variance.sh` compiles a small Metal compute kernel with `swiftc` at runtime. The full Metal and Swift source is inline in the script's heredoc, auditable the same way as everything else: read it before running. Nothing pre-compiled is shipped, the compiled binary lives only in a per-user tempfile deleted on exit, the kernel runs read-mostly FMA math over a scratch buffer, and the phase makes no network calls. If `swiftc` or a Metal device isn't available it skips cleanly. To keep the run fully interpreted, don't pass `--gpu`.

## Privacy in submitted reports

If you submit a report to the (planned) hosted aggregator:

- **Serial numbers are SHA-256 hashed by default.** `inventory.sh` and `battery.sh` emit `serial_hash` instead of the raw serial. The plaintext is included only if you set `INCLUDE_PLAINTEXT_SERIAL=1`. Even then, `./run` keeps the plaintext in the local copy only and never writes it to the submission copy.
- **The hash is obfuscation, not anonymization.** Apple's serial space has limited entropy (~10⁸ combinations per chassis SKU); a determined operator could rainbow-table the original. Use the hash for *deduplication* assumptions, not *untraceability*. A future aggregator deployment should rotate to HMAC-SHA-256 with a deployment-secret salt. See [`Reports/SCHEMA.md`](Reports/SCHEMA.md#hash-caveat-obfuscation-not-anonymization).
- **`_raw_*` fields** in the inventory and battery JSON contain full `system_profiler` / `ioreg` dumps that may include paired Bluetooth device IDs, Wi-Fi SSIDs, USB device serials, and other environment fingerprints. `./run` strips these from the submission copy. They remain in `Reports/local/<filename>.json` (gitignored) for your own debugging.
- **`store_location`, `purchase_date`** are `null` by default and only populated if you opt in.
- **`submission_safe: true`** is the orchestrator's assertion that none of the above leaked through. Always check it before submitting.

## Reporting a vulnerability

If you find a security issue in Shakedown, please report it privately rather than opening a public issue:

- Open a private security advisory at <https://github.com/ugglr/mac-shakedown/security/advisories/new>.

Please include the affected script(s), macOS version, and reproduction steps. A response should arrive within a few days.
