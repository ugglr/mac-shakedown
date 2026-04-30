---
created: 2026-04-29
tags: [context, not-a-defect]
severity: context
detectable-on-site: na
---

# Repairability — Context, Not a Defect

This is **not a defect to test for** — it's context that affects the cost-of-failure equation. Worth knowing because it changes what a "minor issue post-warranty" actually costs you.

## What changed in M5

- More components paired to the logic board via software locks (serialization).
- Donor parts from another M5 won't work without Apple's proprietary configuration software.
- **Battery replacement requires swapping the entire top case** — keyboard, palmrest, battery, all together. iFixit calls this a "crazy procedure."

## Why it matters for verification

- Out-of-warranty battery replacement will be expensive and may require Apple Authorized Service Provider, especially if you're not in a major Apple market.
- An iffy battery on day 1 is much more painful in a few years than on prior models.
- Reinforces the priority of catching battery issues during the verification window — see [Battery Defects](Battery%20Defects.md).

## Sources

- [iFixit — M5 MacBook Pro teardown / battery replacement procedure](https://www.ifixit.com/News/114046/m5-macbook-pro-teardown)
- [iFixit — MacBook Pro 14" 2026 repair guide](https://www.ifixit.com/Device/MacBook_Pro_14%22_2026)
- [New York Computer Help — Joe's Take: same old repair headaches](https://www.newyorkcomputerhelp.com/joes-take-the-m5-macbook-pro-faster-chips-but-same-old-repair-headaches/)
