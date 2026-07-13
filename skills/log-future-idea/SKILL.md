---
name: log-future-idea
description: "Capture conceptual someday project ideas in docs/scratch/future-ideas.md without promoting them to active spikes. Use when the user has a far-future feature, direction, capability, design concept, or exploratory idea that is more coherent than misc intake but not ready for scoped work."
---

# Log Future Idea
## Local Precedence
If the current repo already has `skills/log-future-idea/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Use this skill for conceptual future material: ideas that may matter someday but are not ready to become active work.

Default file:

```text
docs/scratch/future-ideas.md
```

Create it only when the user asks to log a future idea or an existing misc/future-idea triage pass needs it.

## Taxonomy
Use the first matching destination:

- `docs/decisions/` for settled durable rules.
- `docs/pinned-issues.md` for unresolved issues intentionally preserved for later.
- `docs/scratch/future-ideas.md` for conceptual someday material.
- `docs/scratch/misc.md` for raw observed friction, QA nits, bugs, and issue intake.
- `docs/active-spikes/` for active scoped work.

Future ideas are more conceptual and farther-horizon than misc notes. They are not more important, more approved, or more likely to happen.

## What Belongs Here
Good future idea entries are coherent enough to reread later as an idea:

- future capabilities or product directions
- design concepts that need a real phase later
- exploratory architecture or content directions
- feature families that are too early to scope
- retired ideas worth remembering as possible later context

Do not put raw QA observations, nit lists, bug reports, tiny fixes, rambling reaction logs, or unresolved decision questions here. Put those in `misc.md` or `pinned-issues.md`.

## File Shape
Use this shape:

```md
# Future Ideas
Conceptual someday material that is not ready for active spike work.

## Idea Title
Concept: ...

Why it may matter: ...

Current blockers or reasons not now: ...
```

Short bullet entries are fine when the idea is small. Longer sections are fine when the idea already has a coherent shape.

## Workflow
1. Read the current user request and `docs/scratch/future-ideas.md` if it exists.
2. Check nearby `docs/scratch/misc.md`, `docs/pinned-issues.md`, and active spikes if the idea might already be captured.
3. Confirm it is conceptual someday material, not raw issue intake, a durable rule, a pin, or active scoped work.
4. Add or update one entry in `docs/scratch/future-ideas.md`.
5. Preserve the user's framing and why the idea is future-facing.
6. Do not create a spike unless the user is actually starting the work.

## Triage
During later triage:

- Move raw observations out to `docs/scratch/misc.md`.
- Move unresolved questions out to `docs/pinned-issues.md`.
- Promote scoped work into `docs/active-spikes/` through `run-project-spike`.
- Record settled rules under `docs/decisions/`.
- Delete ideas that no longer matter.
