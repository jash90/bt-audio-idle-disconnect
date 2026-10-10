---
title: "Module: bootstrap"
type: module-map
module: bootstrap
updated: 2026-06-05
tags: [codebase, module]
---

# Module: bootstrap — process start and dependency wiring

> The app entry point and manual wiring of all monitors/controllers. 2 files, ~53 LOC.
> This is the "composition root": every new dependency goes through `AppDelegate`.

## Code map

- **Entry points**: `main.swift` creates the `NSApplication`, sets the `AppDelegate`,
  `setActivationPolicy(.accessory)` (no Dock), `app.run()`.
- **Core logic**: `AppDelegate.swift`, in `applicationDidFinishLaunching`:
  notification bootstrap, creating `IdleController` and `MenuBarController`, wiring the
  `AudioMonitor`/`SleepWakeMonitor` callbacks and calling their `start()`.

## How to extend

- New monitor/service? Add the instance as a `private let` (l. 6-10) and wire it in
  `applicationDidFinishLaunching` (l. 33-40). Full list of steps: [[playbook-new-monitor]].
- `.accessory` is why there is no window; see [[adr-003-accessory-menu-bar-only]].

## Common bugs

- *Hypotheses (verify in the code):*
  - A missed `start()` on a new monitor → the instance is alive but does not observe anything.
  - Retain cycle: callbacks use `[weak self]` (pattern l. 33-39); new ones should too.

## Related
[[moc-codebase]] · [[module-orchestration]] · [[module-monitors]] · [[architecture]]
