---
created: 2026-06-02
tags: [verification, methodology, cpu]
---

# Per-core pinning on macOS: what we can and can't do

The CPU variance test (`cpu-variance.sh`) runs one worker per P-core and looks for run-to-run inconsistency. A failure mode it can only partly see: a *single* defective P-core. If one core out of N is slow, the aggregate throughput dips a little and the within-iteration worker spread widens, but the bad core's signal gets diluted across the other healthy workers. The clean fix would be to pin each worker to a specific core and watch one core fall behind. macOS does not let us do that. This note records why, so nobody burns an afternoon rediscovering it.

## There is no public per-core affinity API

- **`thread_policy_set` with `THREAD_AFFINITY_POLICY`.** This is the closest thing in the Mach API, and it is a hint about cache *affinity groups*, never a hard pin to a numbered core. On Apple Silicon it is a no-op: the affinity tag is ignored and the scheduler places threads on whatever cluster and core it wants. On Intel Macs it influenced L2 grouping at best. Either way it cannot say "run this thread on core 3."
- **No `sched_setaffinity` / `taskset` / `cpuset`.** Those are Linux (and FreeBSD `cpuset`). macOS ships nothing equivalent for userspace.
- **QoS only chooses a cluster, not a core.** `pthread_set_qos_class_self_np` and the dispatch QoS classes steer work between the performance (P) and efficiency (E) clusters: `QOS_CLASS_USER_INTERACTIVE` / `USER_INITIATED` lean P, `UTILITY` / `BACKGROUND` lean E. That is cluster selection, not core pinning. Useful for keeping the variance workers off the E-cores (they already run at default QoS, which lands on P under load), useless for isolating one P-core.
- **`os_workgroup` (audio / realtime workgroups)** coordinate scheduling deadlines across threads; they don't pin to cores either.

So on stock macOS, with the constraint that Shakedown ships no compiled binaries and uses no private APIs, there is no way to pin a worker to a chosen core.

## What Shakedown does instead

`cpu-variance.sh` reports `worker_imbalance_pct_per_iter`: within each timed iteration, `(max_worker - min_worker) / max_worker * 100` across the pool. If the macOS scheduler happens to keep one worker on a slow core for an iteration, that worker finishes fewer hashes and the imbalance widens. The thresholds (in [Pass-Fail Criteria](Pass-Fail%20Criteria.md)):

- median imbalance under ~5% is healthy,
- `max_worker_imbalance_pct` over 10% warns,
- over 20% fails (one worker consistently more than 20% behind, the single-core-defect signature).

This is a *partial* mitigation, not a substitute for pinning. Because `multiprocessing.Pool` doesn't pin workers to cores, "worker N" is not "core N", and the scheduler may migrate a worker off the bad core mid-iteration, smearing the signal. The metric catches a persistently slow core often enough to be worth reporting, and the `--noaccel` (BLAKE2b) pass gives a second, non-crypto-accelerated workload that stresses the integer pipelines a defective core is more likely to expose.

## Approaches considered and rejected

- **Oversubscribe workers (spawn 2x P-cores)** to raise the odds that some worker lands on the bad core every iteration. It does raise the odds, but it also adds scheduling noise and context-switch overhead that inflates spread on healthy units, trading one false signal for another. Not worth it at the current iteration length.
- **Read per-core residency from `powermetrics`.** powermetrics reports per-cluster frequency and a coarse per-core active-residency, but the residency numbers don't cleanly map to "this core is defective" under a saturating load (every core reads ~100% busy). It's a thermal/frequency tool, not a per-core throughput tool.
- **A native pinning shim.** A tiny Mach `thread_policy_set` helper would still be ignored on Apple Silicon, and shipping a compiled binary breaks the repo's read-every-line trust property. Not worth it for a no-op.

## Where this could go

A longer single run with statistical attribution (track each pool worker's PID-to-core via `thread_info` sampling, accumulate per-core throughput over many minutes) could expose a slow core without pinning, by letting the scheduler's natural migration cover every core enough times. That's a real project, not a quick win, and it stays on the roadmap rather than blocking the current methodology.
