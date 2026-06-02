---
created: 2026-06-02
tags: [verification, checklist, store]
---

# Store Day Checklist

You, in the Apple Store, on the charger, verifying the machine you just bought before you walk out.

Apple's QA catches the obvious build stuff (speakers, keys, screen). What it has been shipping bad on the M5 is **batch performance variance**: a unit that benchmarks fine once and then craters on a repeat run, invisible in a 30-second look. That is the whole point of this tool, and it is what one command checks.

## Setup (2 min)

- Plug in the charger.
- Get to the desktop (skip Apple ID with "Set Up Later"). **Set a login password** (one step needs it). Join the store Wi-Fi.

## The one command

```bash
xcode-select --install
git clone https://github.com/ugglr/mac-shakedown ~/mac-shakedown
cd ~/mac-shakedown
./run --target mbp-16-m5-max-64 --store
```

- `xcode-select --install` is a one-time GUI dialog (~10 min); the rest is one paste.
- Swap `mbp-16-m5-max-64` for your SKU (see `targets/`), or drop `--target` to auto-detect.
- Enter your login password when it asks for sudo (the thermal phase needs it).
- `--store` is the thorough profile: ~45 min of CPU variance (accelerated **and** non-accelerated), a 10-minute sustained thermal load, the memory triad, and the GPU pass. It takes over; walk around while it runs.
- Want the exact workload the M5 defect was reported on? Add `--llama` (it builds llama.cpp and runs an LLM load; extra time).

## Read the verdict

It ends with a banner: **`SHAKEDOWN VERDICT: PASS`** or **`FAIL`**.

- **PASS** = no performance-defect signature across variance, thermal, memory, GPU.
- A single **WARN** = rerun that phase once (`./Verification/scripts/cpu-variance.sh`). Clears, fine. Warns again, treat as fail.
- **FAIL**, or a WARN that repeats = **exchange at the counter, now.**

## Turn "advisory" into "confident"

The thresholds are still v0.2 (derived from public reports, not yet calibrated against confirmed-good silicon). The one thing that makes a PASS trustworthy is a **comparison**, and it is performance, not cosmetics:

- Run the same `./run --store` (or just Geekbench 6 once + a Cinebench 2024 loop) on a **floor demo of the same model**, and confirm yours lands within a few percent.
- Or diff against a known-good report for your SKU:
  ```bash
  ./Verification/scripts/compare-reports.sh known-good.json Reports/submissions/your-report.json
  ```
- Or eyeball your Geekbench / Cinebench numbers against the published baseline in [Benchmark Reference](Benchmark%20Reference.md) (or live at mianibench.com). A unit 15-20%+ below baseline, or one that swings more than ~10% run to run, is the signature.

## If it fails

Exchange at the counter before you leave the store. Apple Hong Kong is exchange-only and only for a verified defect, so catching it in-store is by far the easiest path. Keep the receipt and the box until it passes.
