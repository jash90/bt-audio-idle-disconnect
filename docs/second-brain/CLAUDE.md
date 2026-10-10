# Second Brain — BT Audio Idle Disconnect

You are the developer operator and navigator of this repo (macOS menu-bar app, Swift/SwiftPM).
Working language: **English** (docs, notes and commit messages in English); Polish is fine when conversing with the user.
Overriding rule: **playbook/note first, code second.**

## What this vault is for
It stores only what **cannot be read from the code**: decisions (why),
procedures (how we do it) and confirmed pitfalls (what burned us). The truth about the code
lives in the code and in `README.md`; the vault links and synthesizes, it does not copy.

## Structure (matches reality)
```
docs/second-brain/
├── CLAUDE.md                 # this file
├── home.md                   # "I want to… → go to" dashboard
├── state.md                  # append-only operations log
├── commands/                 # command sources (bug-triage, new-monitor, sync-code, adr)
├── 5-codebase/               # code map: moc + 7 notes (6 groups + support) + architecture + known-issues
├── 6-playbooks/              # procedures: local-dev, build-release, bug-fix, new-monitor
└── 7-decisions/              # ADRs: template + adr-001..003
```
PARA (0-inbox…4-archives) is skipped on purpose: this is a small, single-package project (thin variant).

## Rules per layer
- **5-codebase/**: pointers to the code; refreshed by `/sync-code`. Notes stay thin (≤~60 lines).
- **6-playbooks/** and **commands/**: twins. If you change one, update the other.
- **7-decisions/**: append-only; an ADR's content is never edited, only `status: superseded`.

## Conventions
- Files: kebab-case ASCII; YAML frontmatter (`title`, `type`, `updated`, `tags`) on every note.
- Notes are written in English.
- Wikilinks in double-bracket format; Mermaid for flows; tables for mappings.
- Every claim about a bug: a `file:line`/README/ticket citation **or** an explicit "hypothesis, verify".

## Commands

| Command | Syntax | Purpose |
|---|---|---|
| `/bug-triage` | `/bug-triage <symptom>` | symptom → module → reproduction → fix → write-back |
| `/new-monitor` | `/new-monitor <Name>` | scaffold a new monitor + registration points |
| `/sync-code` | `/sync-code [scope]` | align the vault with the repo, fix drift/counters |
| `/adr` | `/adr <topic>` | record a decision (4 parts + citation) |
| `/brain` | `/brain <task>` | load context (map+known-issues+module+playbook) before work |

## SSOT
Do not duplicate `README.md` or the code. The vault holds ONLY: ADRs, confirmed
gotchas, mental models, and procedures with a "what gets forgotten" list.

## Dev loop
```
bug/feature → /bug-triage or /brain → work in the repo
   → non-obvious cause?  → add to "Common bugs" in the module note (Confirmed, with file:line)
   → decision made?      → /adr
   → weekly / after merge → /sync-code
```

## Unit definition (coverage contract)
Flat package → unit = **role group** (6) + support. Every `.swift` file/script/resource
MUST have a row in `5-codebase/moc-codebase.md`. `/sync-code` checks this.
