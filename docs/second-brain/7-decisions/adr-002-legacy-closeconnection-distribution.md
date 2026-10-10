---
title: "ADR-002: Legacy closeConnection() + distribution outside the App Store"
type: adr
status: accepted
updated: 2026-06-05
tags: [adr, bluetooth, distribution]
---

# ADR-002: Use IOBluetooth.closeConnection() and distribute outside the App Store

- **Status**: accepted
- **Source**: `Sources/BTAudioIdleDisconnect/BluetoothManager.swift:45`; README "Limitations"

## Context
The core of the product = programmatically disconnecting a paired BT audio device. The only
public API that does this is `IOBluetoothDevice.closeConnection()`: public
but **legacy** and unavailable in the sandbox. Apple offers no sandbox-friendly
alternative for forcing an audio device to disconnect.

## Decision
Use `closeConnection()` as the disconnect mechanism and **give up on the App Store**;
distribute as a direct download (DMG, ad-hoc/notarization).

## Rejected alternatives
- **Sandbox + App Store**: no public sandbox-friendly API for disconnecting;
  the feature is impossible, so the whole app loses its point.
- **Toggling global BT / `blueutil` scripts**: would disconnect
  all devices, not just audio; bad UX and an external dependency.

## Consequences
- ✅ Reliable, selective disconnecting of specific audio devices (Class of Device filter).
- ⚠️ No App Store path: distribution and updates are manual (DMG / GitHub Releases).
- ⚠️ The legacy API may be removed in future macOS versions; a risk to monitor.
- ⚠️ macOS sometimes auto-reconnects the device after a disconnect (see [[known-issues]] K2).

## Related
[[module-bluetooth]] · [[playbook-build-release]] · [[known-issues]]
