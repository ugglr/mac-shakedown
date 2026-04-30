# Security

Shakedown runs entirely on the user's own Mac. The surface area is small: five short shell scripts plus a handful of inline Python heredocs, no external dependencies beyond what ships with macOS, no outbound network calls, and no daemons or persistent components. Everything is local. Auditing the scripts before running them is encouraged — they are pure bash and Python, no minified or obfuscated code, and they are short enough to read end to end in a few minutes.

## What the scripts do with elevated privileges

- `Verification/scripts/thermal-load.sh` invokes `sudo powermetrics` for read-only thermal and CPU-frequency sampling. This is the **only** script that requires elevation, and `powermetrics` is the only command run under `sudo`.
- No other script asks for, requires, or uses elevated privileges.
- All other data collection is unprivileged: SHA-256 over `/dev/urandom` for the CPU workload, hardware facts via `system_profiler` / `ioreg` / `sysctl`, and battery state via `ioreg AppleSmartBattery`.
- Writes are confined to the repo's `Reports/` directory and short-lived tempfiles under `/var/folders/.../shakedown-*` (the system per-user temp area). Nothing is written elsewhere.
- No outbound network requests are made by any script. Reports stay on the local disk unless the user chooses to share them.

## Reporting a vulnerability

If you find a security issue in Shakedown, please report it privately rather than opening a public issue:

- Open a private security advisory at `https://github.com/ugglr/mac-shakedown/security/advisories/new`, or
- Email the maintainer: `<add-email-or-link>`.

Please include the affected script(s), macOS version, and reproduction steps. A response should arrive within a few days.
