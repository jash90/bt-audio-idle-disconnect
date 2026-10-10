---
title: "Home — BT Audio Idle Disconnect Second Brain"
type: dashboard
updated: 2026-06-05
tags: [home, dashboard]
---

# Home — BT Audio Idle Disconnect Second Brain

Operational knowledge for developing, maintaining and fixing the macOS menu-bar app
(Swift/SwiftPM). It stores only what is not in the code. Methodology: [[CLAUDE]].

## I want to… → go to

| I want to… | Go to |
|---|---|
| Fix a bug | [[playbook-bug-fix]] (command: [[bug-triage]]) |
| Add a new monitor / signal source | [[playbook-new-monitor]] (command: [[new-monitor]]) |
| Run and debug locally | [[playbook-local-dev]] |
| Build the bundle / DMG / release | [[playbook-build-release]] |
| Understand the system (mental model) | [[architecture]] |
| Check known limitations | [[known-issues]] |
| Record a decision | [[adr]] (command) |
| Refresh the code map | [[sync-code]] (command) |
| Load full context before work | `/brain <task>` |

## Code map
[[moc-codebase]] is the entry point. Groups:
[[module-bootstrap]] · [[module-monitors]] · [[module-bluetooth]] ·
[[module-orchestration]] · [[module-ui]] · [[module-infrastructure]] · [[module-support]]
· [[architecture]] · [[known-issues]]

## Decisions (ADR)
[[adr-001-ad-hoc-signing]] · [[adr-002-legacy-closeconnection-distribution]] ·
[[adr-003-accessory-menu-bar-only]] · template: [[adr-template]]

## How to start
```bash
cd ~/Projects/bt-audio-idle-disconnect && claude   # dev work: /bug-triage etc.
cd docs/second-brain && claude                     # knowledge work: CLAUDE.md auto-loads
```

## Status (counters)
- `.md` files in the vault: **25**
- Module notes (groups + support): **7** / 7 units ✅ full coverage
- Playbooks: **4** · Commands (sources): **4** · ADRs: **3** + template
- Slash-command wrappers in `.claude/commands/`: **5** (bug-triage, new-monitor, sync-code, adr, brain)
- Link check: **0 broken** (placeholders inside instruction text skipped)

## Recent actions
- 2026-06-05 — vault created (thin variant, single-package). See [[state]].
