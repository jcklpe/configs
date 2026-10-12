---
name: setup-local-skills
description: "Copy reusable seed skill folders into a repository for first-time vendoring, checking portability and required dependencies. Use when the user wants a project to carry its own skills after clone or asks to copy global skills locally."
---

# Setup Local Skills
## Local Precedence
If the current repo already has `skills/setup-local-skills/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Copy complete skill folders from a seed library into the current repo so the repo is self-contained for future agents and collaborators. The copied skill becomes part of the repo's operating contract and may evolve independently.

Use `update-local-skills` when a repo already has the skill and the user wants to refresh, compare, sync, or update it from the global seed version.

Locate the seed library from the user's request, project configuration, or the installed skill catalog. Resolve an installed skill's source when useful; do not assume a personal checkout name or home-directory layout. Ask for the source only if the available context cannot resolve it.

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
2. Locate the seed library and list available skill folders containing `SKILL.md`.
3. Confirm which skills the user wants copied unless the request named them clearly.
4. Check each requested destination before copying anything. If the skill already exists in the repo, use `update-local-skills` for that skill instead of overwriting it. Continue first-time copying only for missing skills.
5. Read each selected new skill and check its supporting resources, paths, and dependencies using the portability check below.
6. Create `skills/` in the repo if missing.
7. Copy each new skill's complete authored folder, preserving `SKILL.md`, metadata, and any `references/`, `scripts/`, or `assets/` folders. Exclude generated caches, `.DS_Store`, secrets, local env files, and unrelated scratch material.
8. Update or suggest updating `AGENTS.md` with local skill precedence.

Prefer a verbatim copy when the source is portable and its required dependencies are available. Do not make silent adaptations on the way in. A reusable defect should be repaired in the seed when that edit is authorized; make any necessary project adaptation explicit and preserve intentional local authority.

Use normal filesystem copy tools available in the environment. Prefer simple, inspectable commands over a custom framework.

## Portable Copies and Local Authority
A reusable skill's authority text should be true no matter which copy is being read. This does not establish that all its referenced tools and resources are available.

The `## Local Precedence` section is written as a *condition* — "if the current repo already has this skill, follow that one first" — which defers correctly when read from the global copy, and is trivially satisfied when read from the local one. Preserve that condition when copying. Later updates still require comparison because the local copy may have deliberately diverged.

Never rewrite a copied skill to assert that it *is* the repo-local one. That statement is deictic: "this repository" resolves against whichever repo the agent is reading from, not against the file's location on disk. A global skill claiming to be authoritative for "this repository" hijacks every project it is invoked in, and tells the agent to ignore that project's actual local copy.

**Seed text states conditions. It never states facts about its own location.**

Keep repository-wide conventions, such as spike placement, in `AGENTS.md` rather than duplicating them across skills. A local skill may intentionally specialize the workflow; preserve that specialization when updating it.

## Portability Check
Check `SKILL.md` and its supporting resources for personal absolute paths, assumed checkout locations, private examples, missing relative targets, and links or symlinks to resources outside the copied folder. Use repository-relative or skill-relative references for supplied resources and documented configuration or discovery for installed dependencies. `~` alone does not make a personal layout portable.

Determine whether required skills, scripts, commands, and assets will be available to the intended cloner. Supply dependencies within the authorized scope or explain the setup they require. Optional integrations and occasional references do not justify copying an entire library. If a required dependency remains missing, report that limitation instead of calling the copied workflow self-contained or usable after clone.

## Local Precedence Text
Add this to `AGENTS.md` when the repo has local skills:

```md
When this repo has `skills/`, repo-local skills are project authority. Prefer `skills/<skill-name>/SKILL.md` over similarly named global skills. Global skills are fallback seed material, not project rules.
```

## After Copying
Verify copied relative references resolve and required dependencies have a documented, available route. A byte-identical copy preserves the source; it does not prove portability. Over time a repo may want its copy to say project-specific things:

- repository-relative paths
- project-specific authority order
- project-specific validation commands
- public/private information boundaries
- naming conventions for docs, scratch files, or spikes

Let those divergences appear when the project needs them, not as a copy-time ritual. Preserve the conditional local-precedence rule.

Report the copied skill folders, explicit adaptations, required dependencies still unavailable, and any existing skills left untouched.
