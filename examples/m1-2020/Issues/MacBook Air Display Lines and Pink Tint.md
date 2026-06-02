---
created: 2026-06-02
tags: [issue, display, m1-air, flex-cable]
severity: medium
detectable-on-site: manual-inspection
---

# M1 MacBook Air / 13" Pro Display Lines, Pink Tint and Pink Flicker

Cable/T-CON-style display issues on the M1 Air and 13" Pro: lines, discoloration, and a pink tint or flicker that changes when the lid is flexed. Credible but anecdotal (single-source), concentrated on the 2020 M1 Air.

## Symptoms

- Horizontal or vertical lines or discoloration bands across the panel.
- Intermittent pink or purple tint, or pink flickering, on part of the screen that changes when the lid is flexed or bent.
- An occasional full pink-screen crash. That last one is a kernel panic (software), not the panel.

## Suspected cause

Display flex cable or T-CON (timing controller) degradation. Lines that disappear at roughly a 45-degree lid angle indicate a damaged or strained flex cable. Pink-when-bent strongly indicates cable breakdown needing a display assembly. Distinguish the panel-level pink flicker (hardware) from a pink-flash-then-reboot kernel panic (software): that distinction is the most valuable, defensible part of this entry.

A note on the "Flexgate-style" label: it is an analogy, not the same defect. Genuine Flexgate is a 2016-2017 MacBook Pro design flaw (too-short flex cable), and Apple's repair program covers only the 2016 13" model. The M1 (2020) machines were never part of Flexgate and use a display where the cable is integrated into the assembly. The evidence here is user-generated repair Q&As plus one forum thread, with no Apple acknowledgment and no major-outlet defect reporting specific to M1, which is why this stays at credible-anecdotal-single-source rather than confirmed.

## Affected scope

MacBook Air M1 (2020, A2237) and MacBook Pro 13" M1 (2020). Reports are isolated-to-recurring and concentrated on the 2020 M1 Air; forum users themselves debate whether the tint is a defect or normal manufacturing variation.

## How to detect on-site

Maps to **Phase 6 (display visual inspection)**. Run solid-color full-screen fields plus white/gray fields at various brightness. Slowly open and close and gently flex the lid to see if lines or tint appear or shift, and tilt to roughly 45 degrees: if lines vanish, suspect the flex cable. A one-off pink flash followed by a reboot is a kernel panic, not necessarily the display, and pink-flash kernel panics could leave `.panic` logs detectable alongside **Phase 8 (Apple Diagnostics)** / log inspection. Not automated.

## Sources

- [iFixit: Why am I experiencing pink flickering on my M1 Mac's display (Answers #792437)](https://www.ifixit.com/Answers/View/792437/Why+am+I+experiencing+pink+flickering+on+my+M1+Mac's+display)
- [iFixit: Horizontal/vertical lines on 2020 M1 MacBook Air display A2237 (Answers #813294)](https://www.ifixit.com/Answers/View/813294/Horizontal-vertical+lines+on+2020+M1+MacBook+Air+display+(A2237))
- [MacRumors Forums: M1 MacBook Air screen issues (thread 2274796)](https://forums.macrumors.com/threads/m1-macbook-air-screen-issues.2274796/)
- [MacRumors: Flexgate MacBook Pro display issue (context, true Flexgate is 2016-2017 only)](https://www.macrumors.com/guide/flexgate-macbook-pro-display-issue/)
- [Apple Community: M1 Air sudden pink screen kernel panic (thread 255323790)](https://discussions.apple.com/thread/255323790)
