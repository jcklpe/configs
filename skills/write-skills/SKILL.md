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

If the observation is real but the fix is not clear, use `log-skills-feedback` when available. Otherwise preserve the evidence and unresolved question in the repository's existing misc or skill-feedback destination; do not require the maintainer's global helper merely to record feedback.

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

- **Global seed skill:** reusable fallback in the user's configured or discovered seed library.
- **Repo-local skill:** project authority under `repo/skills/`.
- **Tool-specific skill:** lives beside the tool and owns that tool's mechanics.
- **Vault-local skill:** project/vault authority inside the vault.

Write seed text as conditions, not deictic facts. "If the current repo already has..." is portable. "This repo's local skill..." is not portable when copied.

## Paths and Dependencies
Do not embed personal absolute paths, usernames, or assumptions about the author's checkout and installation layout in reusable skills. Use repository-relative paths for project resources, skill-relative paths for bundled resources, and documented configuration or discovery for separately installed tools. Replacing a username with `~` does not make a personal folder convention portable. Use an exact system path only when it is an actual tool or platform requirement, and explain that requirement.

Check supporting scripts, references, examples, assets, and metadata as well as `SKILL.md`. Identify the required commands and workflows, how they are located, and what to do if unavailable. Distinguish required dependencies from optional integrations; do not imply that another user has the author's global skills installed. Preserve intentional repository-relative conventions and local authority while making reusable instructions independent of the author's machine.

Select examples for the skill's intended audience. Do not copy private conversation, source material, or local configuration into a reusable skill merely to illustrate its origin.

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
docs/policies/               current durable rules, defaults, and procedures
docs/active-spikes/          active scoped work
```

## Validation
When creating or substantially changing a skill, locate the available validator through the session's skill catalog or configured installation. If `skill-creator` is available, its `scripts/quick_validate.py` path is relative to that installed skill's directory; run it with the target skill directory and a compatible Python environment. Do not guess or embed the current machine's installation address in the instructions. If the validator or its runtime dependencies are unavailable, report that limit and inspect frontmatter and references directly rather than claiming validation passed.

Also check dependency availability and path portability across the complete folder. Frontmatter validation alone does not establish that a skill can be used after cloning.

Forward-test only when the skill is complex enough that another agent may reasonably misapply it. Use realistic prompts and raw artifacts, not your conclusions.
