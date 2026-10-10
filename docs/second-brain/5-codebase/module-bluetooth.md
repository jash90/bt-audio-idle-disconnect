---
title: "Module: bluetooth"
type: module-map
module: bluetooth
updated: 2026-06-05
tags: [codebase, module]
---

# Module: bluetooth — listing and disconnecting devices

> A thin layer over `IOBluetooth`: filters paired devices down to audio ones,
> returns info, disconnects. 1 file (56 LOC). This is where the **controversial** legacy API lives.

## Code map

- **`BluetoothManager.swift`**:
  - `BTDeviceInfo` struct (address, name, isConnected).
  - `pairedAudioDevices()` / `connectedAudioDeviceInfos()`: filtered through `isAudio`.
  - `isAudio(_:)` (l. 51): Major Device Class `0x04` (Audio/Video).
  - `disconnect(address:)` (l. 35): `IOBluetoothDevice.closeConnection()`, logs the `IOReturn`.

## How to extend

- Disconnecting goes by **address** (string), not by object; new calls should too.
- If the audio filter lets through/rejects the wrong devices → touch `isAudio` (Major Class).

## Common bugs

- **Confirmed** (README "Limitations"):
  - `closeConnection()` is public but **legacy**; no sandbox-friendly alternative
    → no App Store (`BluetoothManager.swift:45`). Decision: [[adr-002-legacy-closeconnection-distribution]].
  - macOS may **auto-reconnect** a disconnected device; the log shows `IOReturn=0`
    and the device comes back. This is system behaviour, not a bug. See [[known-issues]].
- *Hypotheses (verify):*
  - `isAudio` relies on the Class of Device; devices reporting an unusual CoD may
    not show up in the list.

## Related
[[moc-codebase]] · [[module-orchestration]] · [[known-issues]] · [[adr-002-legacy-closeconnection-distribution]]
