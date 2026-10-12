---
name: setup-project-docs
description: "Set up or retrofit a repository's durable project documentation for agent-assisted work: root README, .gitignore, AGENTS.md, CLAUDE.md symlink, TODO.md, docs/active-spikes, docs/scratch, docs/archive, docs/policies, optional pinned issues/future ideas, and optional repo-local skills. Use when starting a new repo, adding the spike/scratch/archive/policy workflow to an existing repo, or making repo docs cloneable for future agents and collaborators."
---

# Setup Project Docs
## Local Precedence
If the current repo already has `skills/setup-project-docs/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Set up a low-ceremony docs ecology that lets humans and agents keep context over time without turning every thought into a ticket. The structure should preserve the difference between current policies, active work, scratch thinking, and historical context.

This skill initializes the structure. Use `run-project-spike` to conduct active spike work, `triage-project-misc` to route loose notes, `log-future-idea` to capture conceptual someday material, `pin-issue` to preserve unresolved issues for later, `setup-local-skills` to copy seed skills into a project repo, and `update-local-skills` to refresh existing local skill copies.

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
    policies/
```

Optional, when the repo should carry its own agent workflows:

```text
repo/
  skills/
    run-project-spike/
    triage-project-misc/
```

Use the `setup-local-skills` skill to locate the configured or discovered seed library and copy complete skill folders with their portability and dependency checks. Use `update-local-skills` when the repo already has local skills and the user wants to refresh them from the seed versions. Do not symlink repo-local skills; copied skills are allowed to evolve with the repo.

Do not copy a whole personal skill library into a repo by default. Add repo-local skills only when they are part of how the repo should be operated after clone.

## Review and Skill Dependencies
Read the user's current review and commit preferences and the repository's commit policy before checkpointing setup files. Honor a requested scaffold review period: leave edits uncommitted until the user authorizes the checkpoint. Do not infer permission to push from permission to initialize a repository or make local commits. Outside a requested review period, follow the repository's normal authorized commit workflow rather than adding a new approval ritual.

Before calling the setup complete, check that workflows referenced by `AGENTS.md` and required repo-local skills are available after cloning. Copy the necessary supporting skill folders, scripts, references, and assets when authorized. Do not assume the cloner has the maintainer's global skill installation. Distinguish required workflows from optional tools; do not vendor the whole personal skill library to satisfy incidental references. State where agents should load the local skills, without claiming automatic discovery unless that mechanism has been configured.

The scaffold establishes documentation locations and operating conventions. It does not establish a product specification or preserve the full project discussion. Report which project rationale, references, and open questions have actually been captured, and which remain elsewhere or unwritten. Do not manufacture that missing substance from the folder structure.

## File Roles
Use root `README.md` for the human-facing project overview: what the project is, how to start, and the most important commands or links.

Use `.gitignore` to keep local agent state, OS junk, secrets, env files, tokens, caches, and generated private artifacts out of version control. This skill includes `assets/default.gitignore` as a starter; merge it with existing project-specific ignore rules instead of overwriting a real `.gitignore`.

Use `AGENTS.md` for durable agent instructions: repo layout, validation expectations, safety rules, local skill precedence, and conventions agents must follow. Describe portable project conventions rather than the current maintainer's surrounding workspace, private reference sources, or checkout-specific storage arrangement. Keep machine-specific setup details outside shareable project authority unless they are actual project requirements.

When the repo should support Claude-style repo guidance, symlink `CLAUDE.md` to `AGENTS.md` so the same neutral instructions stay authoritative:

```sh
ln -sf AGENTS.md CLAUDE.md
```

Use `TODO.md` as the short spike index and coordination map. Keep it scan-friendly: active spikes, waiting-for-human-QA, recently archived/completed spikes, and lightweight later ideas. Detailed implementation state belongs in each spike's `.todo.md`.

Use `docs/active-spikes/` for current spike doc pairs. Each active spike should have a conceptual doc and a `.todo.md` companion.

Use `docs/scratch/` for rough, non-authoritative thinking: copied references, early notes, possible future spikes, and `misc.md`.

Use `docs/archive/` for retained closed or superseded spike pairs, which make development history discoverable and connect its subject to Git through a stable spike slug. Follow `run-project-spike` for closure dates and pointers to maintained guidance or continuing work. Archived docs are historical context, not current rules, unless durable docs still agree with them.

Use `docs/policies/` for current, durable project guidance: rules, defaults, procedures, suggested processes, exceptions, and the rationale needed to apply them. Prefer subject-focused files such as `0001-repository-boundaries.md`; numbering is optional and should follow the repository's convention.

Policies describe what applies now. Revise them directly when the approach changes; Git records prior versions and the reasons for changes. Do not default to append-only Architecture Decision Records (ADRs), superseded decision chains, or a required Context / Decision / Consequences format. Keep rationale that helps someone act today, but leave setup chronology and abandoned alternatives in Git history or archived development notes.

A minimal policy might use:

```md
# Repository Boundaries
## Current Approach
What belongs where, and how to operate the arrangement.

## Rationale
Why this arrangement matters for current work.

## Exceptions
Only when real exceptions need explanation.
```

Preserve an existing project's deliberate vocabulary and documentation conventions unless migration is authorized. A new-project default is not permission to rename an existing `decisions/` folder. When no Git history exists, agree on a lightweight way to preserve changes rather than silently treating a current policy as an immutable historical record.

Do not create a `README.md` inside `docs/` or any of its subfolders. In a folder where every file is documentation, `README` names nothing, and such a file inevitably restates the authority rules that already live in `AGENTS.md` while carrying a hand-maintained file listing that `ls` provides for free. `TODO.md` is the index.

Use `docs/pinned-issues.md` only when the repo needs a short register for unresolved issues intentionally preserved for later. Create it with the `pin-issue` skill instead of adding it to every project by default.

Use `docs/scratch/future-ideas.md` only when the repo has conceptual someday material that is more coherent and farther-horizon than raw misc intake. Create it with `log-future-idea`.

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
6. If adding repo-local skills, use `setup-local-skills` to copy full skill folders into `repo/skills/`. If local skills already exist and should be refreshed, use `update-local-skills`.
7. Keep private or sensitive information out of public repos. Use examples and placeholders for local-only values.
8. Check required skill dependencies and distinguish established conventions from project content still needing capture.
9. Report what was created, what was intentionally skipped, and which docs need human review; checkpoint only within the user's current review and commit preferences.
