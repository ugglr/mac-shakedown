---
created: 2026-06-02
tags: [issue, thermal, firmware, performance]
severity: medium
detectable-on-site: only-with-benchmarks
---

# 2018 15" Core i9 Thermal Throttling

A firmware bug on the 2018 15" Core i9 drove clocks below the base speed under sustained load. Fixed by the July 2018 supplemental update.

## Symptoms

- Under sustained load the i9 dropped well below its 2.9GHz base clock, averaging ~2.2GHz with dips as low as ~2.0GHz in Cinebench.
- The i9 could perform worse than the cheaper i7 until patched.

## Suspected cause

Apple confirmed a "missing digital key in the firmware" that broke the thermal management system, driving clocks down under heavy thermal load. The macOS High Sierra 10.13.6 Supplemental Update (July 24, 2018) restored expected behavior (sustained ~3.1-3.5GHz in retesting). Caveat: independent reporting traced the underlying mechanism to VRM power-limit behavior under heat, and even post-patch the 15" still throttled after repeated runs, so the i9-in-this-chassis thermal ceiling was partly genuine physics, not 100% bug. The firmware fix was real and material, but do not overstate that it eliminated all thermal limits.

## Affected scope

MacBook Pro 15" 2018, specifically the Core i9 (and to a lesser degree i7) configurations. Real and broadly reported, but promptly fixed by a free software update, so the practical risk today is only on an un-patched unit or one with a separate cooling defect.

## How to detect on-site

This maps to **Phase 4 CPU variance (early_vs_late_decline, spread) and Phase 5 sustained thermal (frequency_cliff_pct, steady_state_vs_peak, early_cliff_pct)**, which directly target sustained-throttle behavior. First ensure macOS is fully updated (the original bug only affects un-patched firmware). Then run a sustained CPU stress test and watch for clocks collapsing far below base and throughput cliffing. On a patched unit, these phases catch residual thermal-paste or cooling defects rather than the original firmware bug. Read Phase 5 thermal warns on this thin Intel chassis with the harness's weaker-on-Intel caveat in mind (see overview).

## Sources

- [AppleInsider: patch fixes the thermal situation in the 2018 i9 MacBook Pro](https://appleinsider.com/articles/18/07/24/tested-apples-patch-fixes-the-thermal-situation-in-the-2018-i9-macbook-pro)
- [9to5Mac: 2018 MacBook Pro update to fix CPU throttling](https://9to5mac.com/2018/07/24/apple-releases-2018-macbook-pro-update-to-fix-cpu-throttling-thermal-management-bug/)
- [Notebookcheck: software fix for thermal throttling in the 2018 MacBook Pro](https://www.notebookcheck.net/Apple-issues-software-fix-to-address-thermal-throttling-in-the-2018-MacBook-Pro.318232.0.html)
- [Notebookcheck: throttling traced to improperly set VRM power limits](https://www.notebookcheck.net/Throttling-in-the-2018-Core-i9-Apple-MacBook-Pro-traced-to-improperly-set-VRM-power-limits.318176.0.html)
- [HotHardware: 2018 MacBook Pro Core i9 thermal issue](https://hothardware.com/news/2018-macbook-pro-core-i9-thermal-issue)
