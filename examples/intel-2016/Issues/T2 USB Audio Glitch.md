---
created: 2026-06-02
tags: [issue, t2, firmware, audio]
severity: medium
detectable-on-site: partial
---

# T2 USB 2.0 Audio Glitch / Dropouts

A T2 firmware timing-synchronization bug causes clicks, pops, and dropouts in audio carried over USB 2.0. Primarily a pro-audio problem.

## Symptoms

- Periodic clicks, pops, and dropouts in audio streamed over USB 2.0 (USB audio interfaces, some DACs).
- Built-in-speaker crackling was also reported on early 2018 units in apps like Spotify and YouTube.

## Suspected cause

A timing-synchronization bug in the T2 firmware disrupts the clock for audio carried over USB 2.0, causing stream dropouts. Outlets traced it to the T2 overloading the USB 2.0 bus whenever it syncs time and location. Workarounds: use Thunderbolt or USB 3 audio devices, or disable automatic date/time and time-zone syncing. The built-in-speaker crackle was a related but separately reported complaint, largely addressed by the 2018 macOS 10.13.6 Supplemental Update 2.

## Affected scope

All T2 Macs: MacBook Pro 2018-2019, MacBook Air 2018-2019, Mac mini 2018, iMac Pro 2017. Affected gear spanned multiple vendors (Apogee, Focusrite, RME, MOTU, NI, Yamaha), confirming it is hardware/firmware-level, not a single device's fault. Real for the specific population of pro-audio users on T2 Macs with USB 2.0 interfaces; practical workarounds exist.

## How to detect on-site

This maps to **manual Phase 7 (speaker step)** for the built-in-speaker crackle: play a bass-and-treble music clip on the built-in speakers at ~70% and listen for crackle. The USB 2.0-specific dropout requires a USB 2.0 audio device, which most buyers will not have on hand, so it is largely not detectable by the harness without bringing one.

## Sources

- [AppleInsider: pro-audio glitch with T2 Macs on USB 2.0 connections](https://appleinsider.com/articles/19/02/19/pro-audio-glitch-with-t2-equipped-macs-connected-to-usb-20-connections)
- [Eclectic Light: problems with USB 2.0 audio devices and a T2 Mac](https://eclecticlight.co/2019/02/19/having-problems-with-usb-2-0-audio-devices-and-a-t2-mac/)
- [iDropNews: supplemental update for kernel panic and crackling speakers](https://www.idropnews.com/news/macbook-pro-update-hopes-to-fix-kernel-panic-and-crackling-speakers)
- [CDM: Apple 2018 audio glitch](https://cdm.link/2019/02/apple-2018-glitch/)
- [Michael Tsai: T2 Macs have a serious audio glitching bug](https://mjtsai.com/blog/2019/02/19/t2-macs-have-a-serious-audio-glitching-bug/)
- [iDropNews: 5 things to know about the T2 audio bug](https://www.idropnews.com/news/have-a-2018-mac-here-are-5-things-to-know-about-the-new-t2-audio-bug/97126/)
- [AppleInsider: T2 troublesome for some pro audio interface users](https://appleinsider.com/articles/19/02/07/apples-t2-proving-troublesome-for-some-professional-audio-interface-users)
