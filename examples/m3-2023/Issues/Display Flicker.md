---
created: 2026-06-02
tags: [issue, display, software-first]
severity: low
detectable-on-site: partial
---

# Display Flicker

Brief flicker on the internal ProMotion panel (especially in the first hours after wake) or flicker/signal loss on external monitors. Mostly software/display-pipeline related and often mitigable by a refresh-rate toggle; only persistent flicker that survives a current macOS points to hardware.

## Symptoms

- Brief flicker or glitching on the internal ProMotion 120Hz panel after wake, often worst in the first 1-3 hours and on dark/gray content.
- Horizontal-line flicker or every-few-seconds signal loss/blackout on external monitors over USB-C.
- Often resolves by toggling refresh rate (ProMotion to fixed 60Hz and back), moving the mouse, or playing 120Hz content.

## Suspected cause

- Mostly software, display-pipeline, or firmware related. Some internal-flicker reports resolved on their own with no hardware fault identified, and in at least one thread the glitching traced to a high-CPU app rather than the panel.
- External-monitor flicker has no single confirmed fix: some reports resolve after macOS updates, others persist and remain unresolved across releases (MacRumors documents external/Studio Display flicker as an ongoing bug in macOS Tahoe as of Dec 2025, and BenQ states the cause "remains unknown"). Do not assume Apple shipped a targeted fix.
- A persistent flicker that survives a current macOS and a refresh-rate toggle could indicate a genuine panel or cable issue.

## Affected scope

- M3 / M3 Pro / M3 Max MacBook Pro, for both internal ProMotion flicker and external-monitor flicker.
- Single-source / forum-level anecdotes rather than authoritative defect confirmation. The threads themselves often point away from hardware.

## How to detect on-site

Maps to **Phase 6** (display color cycle) plus the manual external-display step. This is software-first triage:

1. Update to the current macOS.
2. Run a fullscreen color cycle and watch for flicker.
3. Toggle ProMotion to fixed 60Hz and back.
4. Test any external display (try a lower refresh rate and a known-good HDMI 2.1 cable).

Only persistent flicker after these steps points to hardware; investigate the panel/cable then.

## Sources

- [Apple Discussions: ProMotion MacBook Pro 16" flicker after wake](https://discussions.apple.com/thread/254890849)
- [Apple Discussions: external monitor flickering on M3 MacBook Pro](https://discussions.apple.com/thread/255500019)
- [Apple Discussions: M3 Pro 16" screen glitching (traced to high-CPU app)](https://discussions.apple.com/thread/255401069)
- [BenQ: how to fix Mac M1/M2/M3 external monitor flicker](https://www.benq.com/en-us/knowledge-center/knowledge/how-to-fix-mac-m1-m2-external-monitor-flicker.html)
- [MacRumors: macOS Tahoe Studio Display flickering still unresolved](https://www.macrumors.com/2025/12/18/macos-tahoe-studio-display-flickering/)
