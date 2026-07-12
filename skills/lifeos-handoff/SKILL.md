---
name: lifeos-handoff
description: "Use when the user asks to hand work off to LifeOS, log an accomplishment or progress update to their LifeOS vault, produce a handoff blurb for career/accomplishments.md, or says 'LifeOS handoff' / 'log this to LifeOS'. Produces a ledger-ready summary in the vault's entry shape from the current session or repo. User-initiated only, never autonomous, and never writes to the vault itself."
---

# LifeOS Handoff
## Local Precedence
If the current repo already has `skills/lifeos-handoff/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## What LifeOS Is
LifeOS is the user's personal life-tracking Markdown vault. Among other things it keeps `career/accomplishments.md`, a durable ledger of concrete work completed — raw material for future resumes, portfolios, case studies, and reviews. An agent working *inside* the vault already knows to harvest accomplishments into that ledger. This skill is the other half: it lets an agent working in **any repo** produce a ledger-ready handoff the user can carry over.

## When To Use
Only when the user asks. Triggers are things like "hand this off to LifeOS", "log this accomplishment", "give me a LifeOS progress update", "LifeOS handoff".

**Never run this on your own initiative.** Do not offer it, do not suggest logging work to LifeOS, do not append it to an unrelated response. Unprompted handoff nudges are noise the user does not want. Silence unless asked.

## What You Produce
Text, for the user to paste into their vault. **You never write to the vault** — it is usually not reachable from the repo you are in, and the user curates what lands.

Two flavors; ask or infer which fits, and do not inflate one into the other:

- **Accomplishment** — a completed, resume-relevant outcome. Emit the full entry shape below.
- **Progress update** — where a project stands and what moved, not necessarily resume-ready. A lighter dated note, suitable for the ledger's harvest queue or a project note.

## The Entry Shape
Match the vault ledger's own shape so the output drops in unedited:

```md
- Date / period:
- Focus:
- Accomplishment:
- Evidence:
- Resume angle:
- Notes:
```

For a progress update, the same skeleton is fine with `Accomplishment:` read as "what moved" and `Resume angle:` often left blank or tentative.

## How To Fill It
Follow the ledger's own guidance, and favor evidence that already exists over prose you invent:

- **Concrete facts.** What changed, who benefited, what artifact or system now exists, what scope was handled.
- **Real evidence.** Prefer things already in the repo: a commit range, an archived spike doc, a shipped file, a PR, a URL. Cite them. `Spike:` trailers and archival summaries in the git log are already synthesized — use them.
- **Numbers only when real.** Never invent metrics. "Reduced a 2,550-line file to 324" is fine if true; "improved performance ~40%" is not, unless measured.
- **No vague praise.** "Did great work on the CLI" is useless to a future resume. State the outcome and the evidence.
- **Coarser than commits.** A handoff summarizes a milestone or a body of shipped work, not every commit. The user does not want LifeOS mirroring repo-level detail — that lives in the repo.

## Where It Goes
Tell the user the destination: paste into `career/accomplishments.md` in the LifeOS vault — into the main ledger if it is resume-ready, or the "Current Harvest Queue" if it is rough. Do not attempt to open or write the vault yourself.

## Example
Asked to hand off a finished refactor, a good output:

```md
- Date / period: 2026-07-11
- Focus: LifeOS Tools CLI maintainability
- Accomplishment: Refactored a 2,550-line monolithic bash CLI into a 324-line dispatcher plus feature modules, with byte-identical behavior verified against a golden baseline.
- Evidence: configs repo, `git log --grep='Spike: lifeos-code-cleanup'`; docs/archive/lifeos-code-cleanup.md
- Resume angle: Refactoring legacy scripts into maintainable, tested modules without regression.
- Notes: Kept bash-3.2 compatibility; reorganized secrets and generated output into dedicated folders.
```
