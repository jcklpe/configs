---
name: lifeos-open-austin
description: "Use when refreshing Open Austin GitHub context into LifeOS through the lifeos CLI. Covers locating the public org repo, running its sync, copying generated snapshots into the vault, and routing public write work back to the org repo instead of duplicating it in private tooling."
---

# LifeOS Open Austin
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-open-austin/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

## Snapshot
```sh
lifeos open-austin-org path
lifeos open-austin-org sync
lifeos open-austin-org sync --qa
```

`sync` runs the local org repo sync at `$OPEN_AUSTIN_ORG_REPO_PATH` (or `~/work/org`), then copies only generated `snapshot/` Markdown into `$LIFEOS_VAULT_PATH/sources/open-austin-org/` (`--qa` writes a local copy instead). Use it when LifeOS needs broad Open Austin GitHub issue/project context. The source of truth stays GitHub and the local org tooling repo; LifeOS receives generated context only. The snapshot includes `issues.md`, `issues/*.md`, `labels.md`, `board-org-kanban.md`, `board-open-roles.md`, and `weekly-summary.md` when present.

Do not copy or inspect the org repo `.env`, `.git`, `.github`, tools, workflows, or token/config files.

## Public Writes Belong In The Org Repo
The LifeOS CLI does not implement Open Austin issue writes. Use the public repo's guarded tool and repo-local skill:

```sh
cd /Users/aslan/work/org
tools/issues/create.sh --title "Task title" --body-file /tmp/issue.md --label infrastructure --assign-me
```

Read `/Users/aslan/work/org/AGENTS.md` and the relevant repo-local skill before a public write. The issue tool is dry-run by default and creates only with `--execute`. Shared weekly-meeting reconciliation follows `/Users/aslan/work/org/skills/process-weekly-meeting/SKILL.md`.

## Safety
- Do not put private strategy, personal bandwidth planning, or sensitive context into public GitHub issues.
- Do not add comments, create or close issues, move project items, or bulk-edit GitHub state unless the user explicitly approves that specific action — comments and issue writes notify real people or change public org state.
- Do not manually edit `sources/open-austin-org/` to change GitHub state.
