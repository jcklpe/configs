---
name: setup-local-skills
description: "Copy reusable seed skill folders from a personal configs skill library into a repository's local skills folder for first-time vendoring. Use when the user wants a project repo to carry its own skills after clone, asks to vendor or copy global skills locally, or wants repo-local skill authority without symlinking."
---

# Setup Local Skills
## Local Precedence
If the current repo already has `skills/setup-local-skills/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Copy complete skill folders from a seed library into the current repo so the repo is self-contained for future agents and collaborators. The copied skill becomes part of the repo's operating contract and may evolve independently.

Use `update-local-skills` when a repo already has the skill and the user wants to refresh, compare, sync, or update it from the global seed version.

Default seed source:

```text
~/configs/skills/
```

Default local target:

```text
repo/skills/
```

## What To Copy
Copy a skill locally when:

- the repo depends on that workflow for normal collaboration
- the skill has repo-specific paths, terminology, or quality rules
- another agent cloning the repo would need the workflow to avoid losing context
- the user wants the workflow to evolve inside this project
- the skill references project docs that should travel with the repo

Keep a skill global-only when it is merely a personal preference, experimental, too broad for the repo, or dependent on private local tooling unavailable to future cloners.

## Copy Workflow
1. Identify the repo root and inspect existing `AGENTS.md`, `skills/`, and docs.
2. List available seed skills from `~/configs/skills/` by looking for first-level folders with `SKILL.md`.
3. Confirm which skills the user wants copied unless the request named them clearly.
4. Create `skills/` in the repo if missing.
5. Copy each requested skill folder wholesale, preserving `SKILL.md` and any `references/`, `scripts/`, or `assets/` folders.
6. Do not copy generated caches, `.DS_Store`, secrets, local env files, or unrelated scratch material.
7. If the skill already exists in the repo, this is an update, not a copy. Use `update-local-skills`.
8. Update or suggest updating `AGENTS.md` with local skill precedence.

Copy the skill **verbatim**. Do not adapt its text on the way in. See "Why Verbatim Copies Are Correct" below.

Use normal filesystem copy tools available in the environment. Prefer simple, inspectable commands over a custom framework.

## Why Verbatim Copies Are Correct
A skill's text must be true no matter which copy of it is being read.

The `## Local Precedence` section is written as a *condition* — "if the current repo already has this skill, follow that one first" — which defers correctly when read from the global copy, and is trivially satisfied when read from the local one. The same bytes are right in both places, so a verbatim copy needs no adaptation and an update can overwrite losslessly.

Never rewrite a copied skill to assert that it *is* the repo-local one. That statement is deictic: "this repository" resolves against whichever repo the agent is reading from, not against the file's location on disk. A global skill claiming to be authoritative for "this repository" hijacks every project it is invoked in, and tells the agent to ignore that project's actual local copy.

**Seed text states conditions. It never states facts about its own location.**

Genuine repo-specific facts — that spike docs live in `notes/` rather than `docs/`, say — belong in the repo's `AGENTS.md`, which already outranks skills, not inside the skill file.

## Local Precedence Text
Add this to `AGENTS.md` when the repo has local skills:

```md
When this repo has `skills/`, repo-local skills are project authority. Prefer
`skills/<skill-name>/SKILL.md` over similarly named global skills. Global skills
are fallback seed material, not project rules.
```

## After Copying
A verbatim copy is already correct, so nothing *must* change. Over time a repo may still want its copy to say project-specific things:

- exact repo paths
- project-specific authority order
- project-specific validation commands
- public/private information boundaries
- naming conventions for docs, scratch files, or spikes

Let those divergences appear when the project needs them, not as a copy-time ritual. Never touch the `## Local Precedence` section.

Report the copied skill folders and any existing skills left untouched.
