---
title: "Command /adr"
type: command
updated: 2026-06-05
tags: [command, dev-workflow, decisions]
---

# /adr — record an architecture decision

> An ADR captures the **why**, which cannot be read from the code. Every ADR must have
> all 4 parts and a citation to real code/config.

## Syntax
`/adr <decision topic>`

## When to write an ADR
- the solution is non-obvious / goes against the default approach,
- it will surprise someone in 3 months,
- ≥2 reasonable options were considered,
- a bug fix revealed a hidden assumption.

## Algorithm

### Step 1 — Number and file
```bash
ls docs/second-brain/7-decisions/adr-*.md   # next number = max + 1
```
Create `7-decisions/adr-NNN-<slug>.md` from the template (`adr-template.md`). Write it in English.

### Step 2 — Fill in ALL 4 parts
- **Context**: what problem forced the decision (2-4 concrete sentences).
- **Decision**: what was decided (1-2 sentences, imperative mood).
- **Rejected alternatives**: what was rejected and WHY (≥1; without it the ADR is invalid).
- **Consequences**: gains **and** costs / what must now be watched.

### Step 3 — Citation (MANDATORY)
In the **Source** field give a `file:line`, a manifest field or a PR. An ADR without a citation is a failure.

### Step 4 — Link it
Add a wikilink to the new ADR (`adr-NNN-<slug>`) to the list in [[home]] and to the related module notes.

## Related
[[home]] · [[adr-template]]
