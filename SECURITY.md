# Security

Shakedown runs entirely on the user's own Mac. The surface area is small: a handful of short shell scripts plus inline Python heredocs, no external dependencies beyond what ships with macOS, and no daemons or persistent components. The default `./run` makes no outbound network calls and runs no third-party code. Everything is local and auditable: the scripts are pure bash and Python, no minified or obfuscated code, short enough to read end to end in a few minutes. Two opt-in exceptions, both off by default and disclosed below: the `--gpu` phase compiles a small Metal kernel at runtime, and the `--llama` phase clones and builds llama.cpp and reaches the network.

## What the scripts do with elevated privileges

- `Verification/scripts/thermal-load.sh` invokes `sudo powermetrics` for read-only thermal, CPU-frequency, and ambient-temp sampling. This is the **only** script that requires elevation, and `powermetrics` is the only command run under `sudo`.
- No other script asks for, requires, or uses elevated privileges.
- All other data collection is unprivileged: SHA-256 over a fixed in-memory 1 MB buffer for the CPU workload (deterministic; no I/O), hardware facts via `system_profiler` / `ioreg` / `sysctl`, and battery state via `ioreg AppleSmartBattery`.
- Writes are confined to the repo's `Reports/` directory and short-lived tempfiles under `/var/folders/.../shakedown-*` (the system per-user temp area). Nothing is written elsewhere.
- The default `./run` makes no outbound network requests. The opt-in `--llama` phase is the sole exception (it clones llama.cpp and may download a model); see below. Reports stay on the local disk unless the user chooses to share them.

## Code that runs beyond pure bash + Python

Three phases go past "interpreted, offline" scripts. The first is on by default but never touches the network; the other two are opt-in and off unless you ask for them. Nothing pre-compiled is ever shipped in the repo.

- **Phase 12 memory bandwidth (default).** `memory-bandwidth.sh` prefers a vendored STREAM triad: it compiles `stream-triad.c` with the `clang` from the Command Line Tools, runs it, and deletes the binary. The C source is in the repo and short enough to read. No network, no shipped binary, no privileges. If `clang` is unavailable it falls back to the pure-Python `memmove` proxy.
- **`--gpu` (opt-in, offline).** `gpu-variance.sh` compiles a small Metal compute kernel with `swiftc` at runtime. The Metal and Swift source is inline in the script's heredoc; read it before running. The compiled binary lives in a per-user tempfile deleted on exit, the kernel runs read-mostly FMA math over a scratch buffer, and it makes no network calls. Skips cleanly if `swiftc` or a Metal device is unavailable.
- **`--llama` (opt-in, reaches the network).** This is the only phase that leaves the machine and runs third-party code. `llama-bench.sh` clones llama.cpp at a pinned ref into `~/.cache/shakedown/llama`, builds it with `cmake`, may download a small GGUF model (a pinned `LLAMA_MODEL_URL`, or a local `LLAMA_MODEL` you provide), and runs `llama-bench`. It is off unless you pass `--llama`, and it skips cleanly when `git` / `cmake` / the network / a model is unavailable. The clone is pinned and the cache is reused, so you can audit exactly what was fetched. The auto-download is not integrity-checked unless you set `LLAMA_MODEL_SHA256` (a complete but corrupted or tampered download would otherwise be cached and run); for a guaranteed-consistent model, point `LLAMA_MODEL` at a local `.gguf` you trust. To keep the run fully offline and free of third-party code, simply don't pass `--llama`.

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
