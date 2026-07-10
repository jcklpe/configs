---
name: setup-project-docs
description: "Set up or retrofit a repository's durable project documentation for agent-assisted work: root README, .gitignore, AGENTS.md, CLAUDE.md symlink, TODO.md, docs/active-spikes, docs/scratch, docs/archive, docs/decisions, and optional repo-local skills. Use when starting a new repo, adding the spike/scratch/archive/decision workflow to an existing repo, or making repo docs cloneable for future agents and collaborators."
---

# Setup Project Docs
## Local Precedence
If the current repo already has `skills/setup-project-docs/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Set up a low-ceremony docs ecology that lets humans and agents keep context over time without turning every thought into a ticket. The structure should preserve the difference between durable rules, active work, scratch thinking, and historical context.

This skill initializes the structure. Use `run-project-spike` to conduct active spike work, `triage-project-misc` to route loose notes, `track-deferred-decisions` to pin decisions that should be revisited later, and `setup-local-skills` to copy seed skills into a project repo.

## Default Structure
Create only what the repo needs, but prefer this baseline for new repos:

```text
repo/
  README.md
  .gitignore
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  TODO.md
  docs/
    active-spikes/
    scratch/
      misc.md
    archive/
    decisions/
```

Optional, when the repo should carry its own agent workflows:

```text
repo/
  skills/
    run-project-spike/
    triage-project-misc/
```

Use the `setup-local-skills` skill to copy full skill folders from the seed library, usually `~/configs/skills/`, into the project. Do not symlink repo-local skills; copied skills are allowed to evolve with the repo.

Do not copy a whole personal skill library into a repo by default. Add repo-local skills only when they are part of how the repo should be operated after clone.

## File Roles
Use root `README.md` for the human-facing project overview: what the project is, how to start, and the most important commands or links.

Use `.gitignore` to keep local agent state, OS junk, secrets, env files, tokens, caches, and generated private artifacts out of version control. This skill includes `assets/default.gitignore` as a starter; merge it with existing project-specific ignore rules instead of overwriting a real `.gitignore`.

Use `AGENTS.md` for durable agent instructions: repo layout, validation expectations, safety rules, local skill precedence, and conventions agents must follow.

When the repo should support Claude-style repo guidance, symlink `CLAUDE.md` to `AGENTS.md` so the same neutral instructions stay authoritative:

```sh
ln -sf AGENTS.md CLAUDE.md
```

Use `TODO.md` as the short spike index and coordination map. Keep it scan-friendly: active spikes, waiting-for-human-QA, recently archived/completed spikes, and lightweight later ideas. Detailed implementation state belongs in each spike's `.todo.md`.

Use `docs/active-spikes/` for current spike doc pairs. Each active spike should have a conceptual doc and a `.todo.md` companion.

Use `docs/scratch/` for rough, non-authoritative thinking: copied references, early notes, possible future spikes, and `misc.md`.

Use `docs/archive/` for closed or superseded spike history. Archived docs are historical context, not current rules, unless durable docs still agree with them.

Use `docs/decisions/` for durable tradeoffs that should outlive a spike. Prefer short numbered records like `0001-docs-workflow.md` when decision records are useful.

Use `docs/deferred-decisions.md` only when the repo needs a short register for intentionally postponed decisions. Create it with the `track-deferred-decisions` skill instead of adding it to every project by default.

## AGENTS.md Baseline
When creating or updating `AGENTS.md`, include these ideas when they fit the repo:

- What the repo is and what kinds of changes belong there.
- Where to put docs, active spikes, scratch notes, generated files, secrets, tests, and local-only state.
- How to validate common changes.
- How to handle dirty worktrees and user changes.
- Whether the repo has `skills/`, and if so: repo-local skills are project authority; global skills are fallback seed material.
- Markdown/prose style: no hard-wrapped prose, minimal reflow-only diffs, touched areas converge over time, and compact heading spacing unless project tooling requires a different layout.
- Public-safety and privacy rules, especially for public repos.
- Whether `CLAUDE.md` is a symlink to `AGENTS.md`.

## Markdown And Prose Style
When creating or updating `AGENTS.md` or other hand-authored docs, include this preference when it fits the repo:

```md
## Markdown And Prose Style
Do not hard-wrap prose in Markdown, comments, docs, or examples. Let editors handle soft wrapping. Preserve paragraphs as single lines unless line breaks carry meaning, such as lists, tables, code blocks, quoted text, frontmatter, or an existing semantic-line-break style.

Avoid reflow-only diffs. When editing prose, change the smallest relevant span instead of rewrapping neighboring paragraphs.

When touching existing Markdown or prose, apply this preferred style to the paragraph, section, or example being edited so files converge over time. Do not mass-reformat untouched sections just to normalize style unless the user asks for a cleanup pass.

Prefer compact Markdown heading spacing in hand-authored docs: do not add blank lines only to separate adjacent headings from each other. Follow existing file style, and let explicit project tooling win when a formatter or linter requires a different layout.
```

## Gitignore Baseline
Create or update `.gitignore` early, before creating local agent settings or secret-bearing files.

Use `assets/default.gitignore` as a starter for common public-repo hygiene:

- `.DS_Store`
- `.claude/`
- `.env` and `.env.*`, while allowing `.env.example`
- token, credential, and local JSON patterns
- logs, caches, and common dependency/build outputs

Merge with ecosystem-specific rules for Node, Python, Rust, static site generators, or any other toolchain already present.

## Scratch And Misc
If the repo needs a loose intake surface, create:

```text
docs/scratch/misc.md
```

Use this minimal shape:

```md
# Misc Inbox
Live inbox for loose observations.

## Unrouted Items
- ...

## Latest Routing Session
Reviewed YYYY-MM-DD.

- ...
```

The detailed routing process belongs in the `triage-project-misc` skill.

## Setup Workflow
1. Inspect the existing repo docs before adding files.
2. Preserve existing conventions when they already solve the same problem.
3. Create missing folders and initial files with the least content needed to make the structure understandable.
4. Add or update `.gitignore` before creating local-only agent or secret files.
5. Add or update `README.md`, `AGENTS.md`, `CLAUDE.md`, and `TODO.md` only with repo-relevant guidance.
6. If adding repo-local skills, use `setup-local-skills` to copy full skill folders into `repo/skills/`.
7. Keep private or sensitive information out of public repos. Use examples and placeholders for local-only values.
8. Report what was created, what was intentionally skipped, and which docs need human review.
