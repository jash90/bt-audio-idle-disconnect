---
title: "ADR-003: Accessory app (menu-bar only), AppKit menu + SwiftUI window"
type: adr
status: accepted
updated: 2026-06-05
tags: [adr, ui, lifecycle]
---

# ADR-003: Run as .accessory (LSUIElement), without a main window

- **Status**: accepted
- **Source**: `Sources/BTAudioIdleDisconnect/main.swift:6` (`setActivationPolicy(.accessory)`);
  `Resources/Info.plist` (`LSUIElement = true`)

## Context
This is a background tool: it watches for silence and disconnects BT. There is no meaningful "main window";
interaction is a menu bar icon + occasional Preferences. A classic app with a window
in the Dock would be confusing and take up space.

## Decision
Set `activationPolicy(.accessory)` + `LSUIElement=true`. UX = `NSStatusItem`
(menu with a countdown, AppKit) and a separate Preferences window in SwiftUI (`TabView`).

## Rejected alternatives
- **A regular app with a window (`.regular`)**: an unnecessary Dock icon and main window
  for a background tool; worse UX.
- **Everything in one UI framework**: a pure SwiftUI menu-bar app (`MenuBarExtra`) is
  weaker at dynamic menus/countdowns on the target macOS 13; pure AppKit would mean
  building the Preferences forms by hand. A hybrid was chosen: AppKit for the menu bar, SwiftUI for the window.

## Consequences
- ✅ A lightweight background tool, no noise in the Dock/app switcher.
- ⚠️ "I can't see a window" confuses users; documented in [[playbook-local-dev]] and [[known-issues]] K7.
- ⚠️ Two UI styles (AppKit + SwiftUI) in one module [[module-ui]]; you need to know both.

## Related
[[module-ui]] · [[module-bootstrap]] · [[known-issues]]
