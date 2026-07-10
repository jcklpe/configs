---
name: setup-local-skills
description: "Copy reusable seed skill folders from a personal configs skill library into the current repository's local skills folder. Use when the user wants a project repo to carry its own skills after clone, asks to vendor or copy global skills locally, or wants repo-local skill authority without symlinking."
---

# Setup Local Skills
## Local Precedence
If the current repo already has `skills/setup-local-skills/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Copy complete skill folders from a seed library into the current repo so the repo is self-contained for future agents and collaborators. The copied skill becomes part of the repo's operating contract and may evolve independently.

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
7. Do not overwrite an existing repo-local skill without showing that it exists and getting explicit approval.
8. Remove or rewrite the copied skill's `## Local Precedence` section so it no longer describes itself as global fallback seed material.
9. Update or suggest updating `AGENTS.md` with local skill precedence.

Use normal filesystem copy tools available in the environment. Prefer simple, inspectable commands over a custom framework.

## Local Precedence Text
Add this to `AGENTS.md` when the repo has local skills:

```md
When this repo has `skills/`, repo-local skills are project authority. Prefer
`skills/<skill-name>/SKILL.md` over similarly named global skills. Global skills
are fallback seed material, not project rules.
```

## After Copying
After copying, inspect the copied skill for generic language that should become project-specific. Good local adaptations include:

- deleting global-only `## Local Precedence` sections
- exact repo paths
- project-specific authority order
- project-specific validation commands
- public/private information boundaries
- naming conventions for docs, scratch files, or spikes

Report the copied skill folders and any existing skills left untouched.
