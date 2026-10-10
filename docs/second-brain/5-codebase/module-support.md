---
title: "Module: support"
type: module-map
module: support
updated: 2026-06-05
tags: [codebase, module, support]
---

# Module: support — build scripts and resources

> Non-executable app code: packaging scripts and static bundle resources.

## Code map

- **`scripts/build-app.sh`**: `swift build -c release` → assembles `BT Audio Idle.app`
  (copies the executable + Info.plist + icon) → **ad-hoc codesign** (l. 27, required for
  notifications and `SMAppService`).
- **`scripts/build-dmg.sh`**: builds the app if missing, reads the version from Info.plist
  (PlistBuddy, l. 19), creates a DMG with a link to `/Applications`.
- **`Resources/Info.plist`**: bundle id `com.bartlomiejzimny.btaudioidle`, `LSUIElement=true`
  (menu-bar only), `NSBluetoothAlwaysUsageDescription`, version `1.0.0`.
- **`Resources/AppIcon.icns`**: bundle icon.

## How to extend

- Version bump: edit `Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`);
  the DMG name picks it up. Full procedure: [[playbook-build-release]].
- New `linkedFramework` → `Package.swift`, not the scripts.

## Common bugs

- **Confirmed**:
  - Without ad-hoc signing (`build-app.sh:27`) notifications and the login item do not work for the recipient.
    Decision: [[adr-001-ad-hoc-signing]].

## Related
[[moc-codebase]] · [[playbook-build-release]] · [[adr-001-ad-hoc-signing]]
