# Skill Taxonomy
Status: active; configs-side implementation committed in `cc7a790 skills: align project workflow taxonomy`.

This spike aligns the personal project workflow skills around a clearer taxonomy for unresolved issues, future ideas, misc intake, durable decisions, active spikes, and reusable skill feedback.

## Goal
Make the common project docs pattern easier for agents to route correctly:

```text
docs/pinned-issues.md        unresolved things intentionally preserved for later
docs/scratch/future-ideas.md conceptual someday material
docs/scratch/misc.md         raw observed friction / issue intake
docs/decisions/              settled durable rules
docs/active-spikes/          active scoped work
```

The practical problem is cross-contamination. `misc.md` should not become a future-ideas essay, `future-ideas.md` should not become a QA nit log, pinned issues should not pretend every pin becomes a decision record, and decision records should stay reserved for durable rules.

## Scope
- Rename the global `track-deferred-decisions` seed skill to `pin-issue`.
- Rename the configs register from `docs/deferred-decisions.md` to `docs/pinned-issues.md`.
- Add global seed skills for `log-future-idea`, `log-skills-feedback`, `write-skills`, and `update-local-skills`.
- Add `agents/skills-feedback-log.md` as the cross-project feedback register.
- Update related global skills so they coordinate the taxonomy.
- Vendor or update the local skill copies in LifeOS and `my-website` once the global seeds are coherent.

## Non-Goals
- Do not force every project to carry every workflow file before it needs one.
- Do not let agents automatically rewrite skills from every observation.
- Do not make skill writing as strict as the Superpowers TDD loop; use its good advice without importing the whole ceremony.
- Do not erase project-local skill divergence while updating local copies.

## Current Model
Use the first matching category:

- If it is a durable rule the project is adopting, write a decision record under `docs/decisions/`.
- If it is an unresolved issue, question, concern, or tradeoff being intentionally preserved for later, use `docs/pinned-issues.md`.
- If it is conceptual someday material, use `docs/scratch/future-ideas.md`.
- If it is raw observed friction, QA notes, bugs, nits, or issue intake, use `docs/scratch/misc.md`.
- If it is active scoped work, use `docs/active-spikes/`.
- If it is reusable skill/process feedback that crosses project boundaries, use `agents/skills-feedback-log.md`.

## Local Vendoring
Local projects should carry the skills that shape their normal workflow. Updating those copies needs to preserve local authority: read global and local versions, identify upstream changes and local divergence, and avoid silent overwrites.

## Outcome
The configs seed layer now carries the taxonomy directly:

- `pin-issue` owns `docs/pinned-issues.md`.
- `log-future-idea` owns `docs/scratch/future-ideas.md`.
- `triage-project-misc` routes raw issue intake without leaking future concepts or pins into misc.
- `write-skills` captures light-touch skill authoring guidance.
- `log-skills-feedback` writes cross-project skill observations to `agents/skills-feedback-log.md`.
- `update-local-skills` owns refreshes of existing repo-local skill copies.

The LifeOS vault has been migrated to the same model, including individual decision records under `docs/decisions/`.

The `my-website` project has local migration edits in its working tree but they are intentionally uncommitted from this repo. Its current docs/skills link check passes when archived historical docs are excluded.
