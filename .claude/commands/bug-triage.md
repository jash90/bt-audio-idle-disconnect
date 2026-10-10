---
description: Bug triage: symptom → module → reproduction → fix (BT Audio second brain)
---

First check `docs/second-brain/5-codebase/known-issues.md`: the symptom may be a known
limitation (by design), not a bug.

Then read `docs/second-brain/commands/bug-triage.md` and run the algorithm described there
step by step for: $ARGUMENTS

Finally, do the closing step: add confirmed gotchas to the module note
(`docs/second-brain/5-codebase/module-*.md`, in English), and record any decision via `/adr`.
