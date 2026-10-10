---
title: "Command /sync-code"
type: command
updated: 2026-06-05
tags: [command, dev-workflow, maintenance]
---

# /sync-code — align the vault with the repo

> Notes in `5-codebase/` are pointers, not copies of the code, and they drift over time.
> This command detects and fixes the drift.

## Syntax
`/sync-code [scope]`  (no argument = everything)

## Algorithm

### Step 1 — Re-enumerate units (coverage)
```bash
cd ~/Projects/bt-audio-idle-disconnect
ls -1 Sources/BTAudioIdleDisconnect/*.swift   # 13 files
ls -1 scripts/*.sh                            # 2 scripts
ls -1 Resources/                              # Info.plist, AppIcon.icns
```
**Unit definition in this repo (flat package):** a unit is a *role group*, not
a single file. Every `.swift` file + script + resource MUST have a row in the
`moc-codebase.md` table mapping it to a group note. Check:
- the number of `module-*.md` notes == the number of groups (6),
- every file from `ls` has its row in the moc (no silent gaps).

### Step 2 — Fact drift
For every module note, check whether the cited `file:line` still points at what
it describes. The most common drift:
- numbers (LOC, file count) in `moc-codebase` → refresh with `wc -l`,
- a new field in `GlobalSettings` (`SettingsStore.swift`) not described,
- a new framework in `Package.swift` (`linkedFramework`) not mentioned in [[architecture]].

### Step 3 — Links and counters
```bash
python3 ~/.claude/skills/engineering-second-brain/scripts/check_links.py docs/second-brain
find docs/second-brain -name '*.md' | wc -l
```
The `find` result must match the counters in `home.md` and the latest `state.md` entry.
Update the counters **at the very end** (after all other `.md` changes).

### Step 4 — Close the loop
- [ ] Add an entry to `state.md` (date + what was synced), in English.
- [ ] If a dangling link or a wrong counter was fixed, note it.

## Related
[[moc-codebase]] · [[home]]
