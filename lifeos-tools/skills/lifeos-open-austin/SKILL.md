---
name: lifeos-open-austin
description: "Use when Open Austin work touches the public open-austin/org GitHub repo through the lifeos CLI: syncing the GitHub snapshot into the vault, or creating issues (dry-run by default, --execute to write). Covers the public/private boundary and the issue-creation approval gates."
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

## Creating Issues
Use this only when Open Austin work needs to be public / org-visible in GitHub. Private strategy, personal bandwidth planning, or sensitive context belongs in LifeOS or Trello instead.

```sh
lifeos open-austin-org create-issue --title "Task title" --body "Context" --label infrastructure --assign-me
lifeos open-austin-org create-issue --title "Task title" --body-file /tmp/issue.md --label board --assign-me --execute
```

The command is **dry-run by default** and prints the plan; it creates an issue only with `--execute`. After creating one it refreshes `sources/open-austin-org/` unless `--no-sync` is passed. Allowed fields: title, body/body-file, labels, assignees, repo override. Before `--execute`, the user should have approved the exact title/body/labels/assignees.

## Safety
- Do not put private strategy, personal bandwidth planning, or sensitive context into public GitHub issues.
- Do not add comments, close/reopen issues, move project items, or bulk-edit GitHub state unless the user explicitly approves that specific action — comments and issue writes notify real people or change public org state.
- Do not manually edit `sources/open-austin-org/` to change GitHub state.
