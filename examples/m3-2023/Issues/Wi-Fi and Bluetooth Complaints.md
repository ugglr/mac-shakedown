---
created: 2026-06-02
tags: [issue, wifi, bluetooth, environment-dependent]
severity: low
detectable-on-site: no
---

# Wi-Fi and Bluetooth Complaints

Scattered reports of weak 5GHz signal, packet loss, or Bluetooth pairing failures on M3 MacBook Pro and MacBook Air. Real but intermittent, strongly environment- and firmware-dependent, with no corroborated hardware-defect pattern specific to M3 radios.

## Symptoms

- Lower-than-expected Wi-Fi signal or high packet loss on the Mac while other devices on the same network are fine (one user documented ~60% packet loss pinging the gateway while other devices showed zero loss).
- Bluetooth devices failing to connect on an otherwise new machine.

## Suspected cause

- Mixed and largely environmental: router/mesh interaction, modem firmware, and USB3 2.4GHz RF interference are repeatedly cited as the actual cause. The USB3/2.4GHz interference cause is Apple's own documented guidance and is a long-standing cross-generation phenomenon, not an M3-specific fault. A moderator in one thread attributes Bluetooth pairing failures to USB3 RF interference and advises moving dongles away from the hinge antennas.
- Some users fixed it by updating modem firmware, switching to 2.4GHz, or reverting a router/mesh change.
- No corroborated hardware-defect pattern specific to M3 radios. No Apple recall, and no editorial outlet reports a systemic M3 radio defect. The chatter spans several forum threads, but none rise above user anecdote.

## Affected scope

- Scattered reports across M3 MacBook Pro (14"/16") and M3 MacBook Air (2024). No evidence of a batch defect.

## How to detect on-site

Not directly covered by the current automated phases (there is no network test in the harness), so this is effectively **not-detectable by the harness** and is a manual check only.

If checking manually: test Wi-Fi throughput and ping/packet-loss on a known-good network with other devices for comparison, and pair a Bluetooth device. Rule out router and interference before suspecting the Mac. This is a candidate calibration note, not a defect.

## Sources

- [Apple Discussions: New MacBook Pro M3 slow Wi-Fi since setup](https://discussions.apple.com/thread/255358715)
- [Apple Discussions: Brand new M3 Pro not connecting to Bluetooth devices](https://discussions.apple.com/thread/255637598)
- [Apple Discussions: M3 Max slow internet despite fast Wi-Fi (~60% packet loss)](https://discussions.apple.com/thread/255416150)
- [MacRumors forums: help with Wi-Fi on MacBook Pro M3](https://forums.macrumors.com/threads/help-with-wifi-on-macbook-pro-m3.2422326/)
- [Apple Discussions: M3 MacBook Pro Wi-Fi 5GHz issues](https://discussions.apple.com/thread/255436006)
