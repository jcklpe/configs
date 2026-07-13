---
name: write-skills
description: "Create or materially revise Codex/Claude skills with concise trigger-focused frontmatter, clear scope, local authority, and evidence-backed workflow guidance. Use when the user asks to make a new skill, rename or split a skill, improve skill authoring guidance, or turn a repeated agent workflow into reusable skill instructions."
---

# Write Skills
## Purpose
Use this skill when creating or materially revising reusable agent skills. Keep the process light: skills are durable workflow guidance, not ceremony.

## Before Writing
Start from observed need. A good skill usually comes from:

- a workflow agents will repeat
- a failure mode that already happened
- a user phrase that should trigger a specific process
- project-local rules that future agents need after clone
- a tool integration whose safety boundaries are easy to forget

Prefer updating an existing skill when the user-facing trigger is the same. Create a new skill when the trigger, workflow, or authority boundary is genuinely distinct.

If the observation is real but the fix is not clear, use `log-skills-feedback` instead of editing a skill immediately.

## Naming
Use lowercase hyphenated names. Prefer short imperative verb-noun names when the skill is an action:

- `pin-issue`
- `log-future-idea`
- `update-local-skills`
- `triage-project-misc`

Use noun names only when the user naturally invokes the capability that way.

## Frontmatter
The `description` is for triggering. It should answer: **why would an agent use this skill now?**

Write descriptions as concise trigger language:

```yaml
description: "Update existing repo-local skill copies from global seed skills while preserving local divergence. Use when the user asks to refresh, sync, compare, or update local skills from their global/source versions."
```

Do not spend description tokens on implementation detail that only matters after the skill has loaded.

## Body Shape
Keep `SKILL.md` lean. Include:

- purpose
- authority and precedence, when relevant
- file locations and default paths
- taxonomy or routing rules, when the skill decides between destinations
- the workflow steps that protect against likely mistakes
- what not to do
- minimal examples only when they clarify ambiguity

Avoid auxiliary docs unless progressive disclosure is useful. If the skill approaches 500 lines or has variant-specific detail, split direct references under `references/`.

## Authority
Be explicit about where the skill applies:

- **Global seed skill:** reusable fallback under `~/configs/skills/`.
- **Repo-local skill:** project authority under `repo/skills/`.
- **Tool-specific skill:** lives beside the tool and owns that tool's mechanics.
- **Vault-local skill:** project/vault authority inside the vault.

Write seed text as conditions, not deictic facts. "If the current repo already has..." is portable. "This repo's local skill..." is not portable when copied.

## Boundaries
Every skill should make its non-goals discoverable:

- when not to use it
- what file or system owns adjacent work
- when to ask the user instead of guessing
- what writes are unsafe or require explicit approval

For project workflow skills, coordinate with the shared taxonomy:

```text
docs/pinned-issues.md        unresolved things intentionally preserved for later
docs/scratch/future-ideas.md conceptual someday material
docs/scratch/misc.md         raw observed friction / issue intake
docs/decisions/              settled durable rules
docs/active-spikes/          active scoped work
```

## Validation
Run the skill validator when creating or substantially changing a skill:

```sh
python3 /Users/aslan/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/<skill-name>
```

Forward-test only when the skill is complex enough that another agent may reasonably misapply it. Use realistic prompts and raw artifacts, not your conclusions.
