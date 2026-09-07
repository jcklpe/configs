---
name: lifeos-github
description: "Use when syncing GitHub context into LifeOS through the lifeos CLI: refreshing issues, pull requests, Discussions, and Projects v2 board state for any configured repo into sources/github/. Read-only snapshots — this does not write to GitHub."
---

# LifeOS GitHub
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-github/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

## What It Does
Pulls open issues, open pull requests, Discussions, and Projects v2 board state for a configured set of repos into `sources/github/<owner>-<repo>/`.

```sh
lifeos github list-repos              # what is configured
lifeos github sync                    # every configured repo
lifeos github sync hai                # one repo, by alias
lifeos github sync --qa               # write to lifeos-tools/qa/ instead of the vault
lifeos github sync --output DIR       # write somewhere specific
```

## Read-Only
**This command never writes to GitHub.** No issue creation, no labeling, no board moves, no comments. Snapshots are context, not a control surface — editing one changes nothing on GitHub. To change GitHub state, use `gh` directly, subject to whatever approval rules that repo's own `AGENTS.md` sets.

Board **automation** is a separate matter and lives where it belongs: Open Austin's board routing, status sync, and archiving run as GitHub Actions workflows inside `open-austin/org`. Nothing here touches them, and nothing here should try to reproduce them.

## Auth
Authentication is whatever `gh auth status` reports. No token is stored in the LifeOS tooling, and none belongs there. If sync fails on auth, run `gh auth login`.

A repo whose Issues or Discussions are disabled produces a warning and is skipped rather than failing the run, so one misconfigured entry cannot break a full sync.

## Configuration
Repos are listed in the gitignored `lifeos-tools/secrets/github-repos.json` — copy `github-repos.example.json`. Each entry:

- `alias` — the short name `sync` takes as an argument
- `owner` / `repo`
- `issues`, `prs`, `discussions` — booleans, default `true`/`false`/`false`
- `projects` — a list of `{number, name}` Projects v2 boards; `name` becomes the filename
- `project_owner` — only when the board belongs to an org other than `owner`

## Output Shape
```text
sources/github/<owner>-<repo>/
  issues.md              index, grouped by first label
  issues/<number>.md     full body plus the whole comment thread
  pull-requests.md       index (omitted entirely when there are none)
  pull-requests/<n>.md
  discussions.md         grouped by category
  board-<name>.md        Projects v2 items grouped by status column
```

Index files are orientation layers, not mirrors: a 160-character preview per item, with full text in the detail file. That follows LifeOS decision 0002 and keeps `sources/` scannable.

Detail directories are **rebuilt** on every sync, so an issue that closes stops appearing. Do not assume a file's presence means the item is still open — the index is the authority on what is open.

## When To Sync
Before reasoning about current state in any repo the vault tracks. A stale snapshot that reports closed issues as open is worse than no snapshot, and it is the failure mode most likely to embarrass you in front of other people.

## Boundaries
- Do not hand-edit anything under `sources/github/`. It is regenerated wholesale.
- Do not add a repo to the config just because it exists. Every entry costs sync time and snapshot size; add repos whose issue state the vault actually reasons about.
- Discussions can be long. The snapshot carries a preview and a comment count, not the thread. Read the thread on GitHub when a specific one matters.
