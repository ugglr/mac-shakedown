---
created: 2026-06-02
tags: [issue, wifi, mac-mini, rf, design-behavior]
severity: low
detectable-on-site: manual-inspection
---

# Mac mini Wi-Fi Near Docks

Wi-Fi throughput on the Mac mini M4 drops when the unit sits on or near a metal dock or external drive. Confirmed by multiple outlets, but it is RF physics rather than a manufacturing defect.

## Symptoms

- Wi-Fi throughput drops, sometimes to the point of an unresponsive connection, when external storage or a dock is connected or placed adjacent to the unit.
- Repositioning the Mac mini onto a plain surface, away from metal enclosures, restores normal throughput.

## Suspected cause

The Wi-Fi antenna sits under the very thin plastic base, because the aluminum case has no antenna break. A nearby metal enclosure (a dock, or an external drive's metal case) attenuates the signal. This is a design / RF-physics behavior, not a defect. Note that off-brand or poorly shielded USB cables can produce the same symptom independent of any dock.

## Affected scope

- Mac mini M4 and M4 Pro (2024). There is no M4 Max Mac mini.
- Real user-facing throughput loss, but easily mitigated: reposition the unit, or use a better-shielded / longer cable. That is why severity stays low.

## How to detect on-site

Manual inspection only. The harness does not measure RF throughput against placement. To check by hand: compare RSSI / throughput with the unit on a plain surface versus on or beside the dock or drive. A drop that recovers when you move the unit confirms the interaction. If a buyer reports flaky Wi-Fi on a Mac mini M4, this is the first thing to rule out before suspecting a hardware fault, and it is context, not a return reason on its own.

## Sources

- [AppleInsider: How to fix weak Wi-Fi on an M4 Mac mini connected to a drive or dock](https://appleinsider.com/inside/mac-mini/tips/how-to-fix-weak-wi-fi-on-a-m4-mac-mini-when-connected-to-a-drive-or-dock)
- [Michael Tsai: Weak M4 Mac mini Wi-Fi](https://mjtsai.com/blog/2025/03/10/weak-m4-mac-mini-wi-fi/)
- [Apple Discussions: Mac mini M4 Wi-Fi unresponsive](https://discussions.apple.com/thread/255860420)
- [Hacker News: discussion of the AppleInsider report](https://news.ycombinator.com/item?id=43332832)
- [MacRumors: new M4 mini Wi-Fi video thread](https://forums.macrumors.com/threads/if-you-have-a-new-mac-m4-mini-you-need-to-watch-this-video.2446672/)
- [Jason Deegan: docks block Wi-Fi signals on the Mac mini M4](https://jasondeegan.com/beware-some-docks-block-wifi-signals-on-the-mac-mini-m4/)
