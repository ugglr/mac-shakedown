---
created: 2026-06-02
tags: [issue, critical, ssd, storage]
severity: high
detectable-on-site: partial
---

# 13" Non-Touch-Bar 2017-2018 SSD Data-Loss / Failure

A batch defect in the SSDs of the entry "Function Key" 13" MacBook Pro that can cause sudden drive failure and data loss. Covered by a now-ended Apple SSD Service Program.

## Symptoms

- Sudden drive failure and potential data loss.
- Because the NAND is soldered, data on a failed unit is generally unrecoverable.

## Suspected cause

Apple did not publicly disclose the exact mechanism. It determined a defect in the 128GB and 256GB SSDs of this specific batch that "can result in data loss and failure of the drive." Note: the affected 2017 non-Touch-Bar 13" model does NOT have a T2 chip (the T2 first shipped in the 2018 Touch Bar MacBook Pro and iMac Pro), so the "unrecoverable" property follows from the soldered NAND, not from T2 encryption. The remedy was reported inconsistently across outlets, as a firmware-update utility and/or a physical SSD replacement.

## Affected scope

13-inch MacBook Pro WITHOUT Touch Bar (the "Function Key" model), with a 128GB or 256GB SSD, sold June 2017 to June 2018. Touch Bar 13" and other capacities are not covered. Apple's SSD Service Program ran for 3 years from sale and has now ended (last eligible units aged out around mid-2021), so on a 2026 purchase this is an out-of-pocket repair.

## How to detect on-site

This maps to **Phase 11 SSD sequential test (ssd-test.sh) plus the Phase 1 inventory SMART check**, which can catch an SSD that is already degrading or failing reads/writes. A latent-but-currently-healthy defective drive is NOT detectable, so treat SKU identification in Phase 1 inventory as the real screen here: confirm whether the unit is the affected SKU (13" non-Touch-Bar, 128/256GB), check SMART status, and run an SSD read/write test. A healthy result does not rule out the latent defect, but a failing one is decisive. Advise the buyer this batch could fail without warning and the program is now closed.

## Sources

- [AppleInsider: replacement program for 13" MacBook Pro SSDs, data-loss warning](https://appleinsider.com/articles/18/11/09/apple-launches-replacement-program-for-13-inch-macbook-pro-ssds-warns-of-data-loss)
- [MacRumors: Apple MacBook Pro SSD service program](https://www.macrumors.com/2018/11/09/apple-macbook-pro-ssd-service-program/)
- [Macworld: 13" MacBook Pro SSD service program FAQ](https://www.macworld.com/article/232110/13-inch-macbook-pro-ssd-service-program-faq.html)
- [iMore: 13" MacBook Pro non-Touch-Bar SSD service program](https://www.imore.com/13-inch-macbook-pro-non-touch-bar-gets-ssd-service-program)
- [iClarified: SSD repair program for 13" MacBook Pro without Touch Bar](https://www.iclarified.com/68275/apple-launches-ssd-repair-program-for-13inch-macbook-pro-without-touch-bar)
