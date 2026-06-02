---
created: 2026-06-02
tags: [issue, imac, display, latent]
severity: high
detectable-on-site: no
---

# iMac 24" Display Flex-Cable Failure (Persistent Horizontal Lines)

Dark horizontal lines appear and persist on the iMac 24" display as a high-brightness flex cable degrades over time. The failure mode is real and severe where it occurs, but it is latent (onset around the 2-year mark) and the M3-specific attribution rests on a single anecdote.

## Symptoms

- Dark or black horizontal line(s) appear and persist across the screen, typically starting near the bottom and worsening over time.
- Onset is usually around 18-24 months (some reports say 2-3 years) after purchase, so most M3 units are only now entering the window.
- Often correlates with sustained high brightness.

## Suspected cause

- The display flex cable carries roughly 50V at high brightness and overheats/degrades over time, causing short-circuits at the connector.
- The cable is bonded into the display assembly, so the only reliable fix is a full display-assembly replacement (reported ~$600-700, out of warranty for most units).
- Apple has not acknowledged it as a manufacturing defect and there is no service program.

**Confidence and scope caveat.** The mechanism is well corroborated on the **M1 iMac 24" (2021)**: Tom's Hardware is the primary source, and iFixit Answers independently documents the ~50V FFC/FPC flex-cable burnout. The **M3 attribution is single-anecdote**: every outlet traces the M3 angle to one forum poster who bought an M3 iMac in May 2024 and reported "similar" lines. There is no second independent M3 case in the cited sources, and the news coverage effectively originates from Tom's Hardware plus aggregators (TUAW explicitly cites Tom's Hardware, so it is not independent corroboration). Treat this as a credible inherited-design risk for the M3 iMac, not a confirmed M3 batch-failure pattern.

## Affected scope

- iMac 24" Apple Silicon family. Design originates on the M1 iMac (2021) and is now beginning to be reported on the M3 iMac (2023, purchased 2024).
- Affects the all-in-one display assembly. Does not apply to the MacBook Pro or MacBook Air SKUs.

## How to detect on-site

Maps to **Phase 6** (manual fullscreen display color-cycle / visual inspection). Run the screen at full brightness through a fullscreen color cycle, especially solid white and solid colors, looking for any faint horizontal banding.

Because the defect is latent and time/heat-dependent, a clean inspection does **not** rule it out: at point of sale a unit will almost always look clean. The harness generally cannot pre-empt it on a fresh unit, so effectively this is not-detectable at purchase. For a used M3 iMac, ask the seller's purchase date and inspect at max brightness across all colors. A Phase 6 WARN on an older M3 iMac display is the cue to point the inspector at this note.

## Sources

- [Tom's Hardware: Apple Silicon iMacs appear to suffer screen deterioration after two years](https://www.tomshardware.com/software/macos/apple-silicon-imacs-appear-to-suffer-from-screen-deterioration-after-two-years-flood-of-user-complaints-hit-apple-community-forums)
- [iFixit Answers: Horizontal lines over iMac 24 screen](https://www.ifixit.com/Answers/View/805617/Horizontal+lines+over+iMac+24+screen)
- [iPhoneInCanada: M1 iMac display lines, bad cable](https://www.iphoneincanada.ca/2024/10/07/m1-imac-display-lines-bad-cable/)
- [Apple Discussions: iMac 24 screen failure (M1 unit, ~32 months)](https://discussions.apple.com/thread/256060429)
- [TUAW: Apple Silicon iMacs face screen issues after two years](https://www.tuaw.com/2024/10/14/apple-silicon-imacs-face-screen-issues-after-two-years/)
- [MacRumors forums: iMac screen suddenly has lines at the bottom](https://forums.macrumors.com/threads/what-the-my-imac-screen-suddenly-have-these-lines-at-the-bottom.2469848/)
- [Apple Discussions: thread cited as the M3 case (unverified, HTTP 429)](https://discussions.apple.com/thread/256079390)
