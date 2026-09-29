---
name: lifeos-github
description: "Use when syncing GitHub context into LifeOS through the lifeos CLI: refreshing issues, pull requests, Discussions, and Projects v2 board state for any configured repo into sources/github/. Also covers the two gated writes: create-issue and Projects v2 board move-card."
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

Creating an issue is the one write, and it is dry-run by default:

```sh
lifeos github create-issue --repo hai --title "..." --body-file /tmp/body.md --label agent
lifeos github create-issue --repo open-austin/org --title "..." --body "..." --assign-me --execute
```

`--repo` takes a configured alias or a literal `OWNER/REPO`, so a one-off issue in an untracked repo works without editing config. Without `--execute` it prints the exact plan — repo, title, body preview, labels, assignees — and creates nothing.

## The Write Boundary
**`sync` never writes.** Snapshots are context, not a control surface — editing one changes nothing on GitHub.

**The tool has two writes, `create-issue` and `move-card`, and both are gated.** Dry-run by default; `--execute` is required. Everything else — labeling an existing issue, closing, commenting, editing — goes through `gh` directly, subject to whatever approval rules that repo's own `AGENTS.md` sets. Open Austin's, for instance, requires explicit approval for all of those.

### Board Moves Are Supported, With A Latency Caveat
```sh
lifeos github move-card --repo hai --issue 18 --status Active
lifeos github move-card --repo open-austin --issue 545 --status Done --execute
```

Dry-run by default; an unknown column lists the valid ones rather than failing blankly.

**A board move is a legitimate input to the automation, not a fight with it.** Both tracked repos wire board and issue state together deliberately: moving a card to Done triggers GitHub's native `Auto-close issue` and the issue closes; moving one out of a terminal column is picked up by a reconciler that reopens it. That is the designed path, documented in `open-austin/org`'s `docs/decisions/0005-board-sync-architecture.md`.

**The real caveat is latency, not conflict.** Card→close is instant because it is native. Card→reopen is cron-driven — `*/5` in the org repo, `*/15` in HAI — and GitHub delays scheduled runs under load, with a measured first reopen taking 25+ minutes. **So a sync run immediately after a move will show the board and the issue disagreeing, and that is expected rather than broken.** Re-sync later.

**Approval still applies.** `open-austin/org`'s `AGENTS.md` forbids agents from moving board items without explicit approval. That is a policy about who decides, not a claim that the capability is unsafe — do not confuse the two, and get approval before `--execute`.

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
  discussions.md         index, grouped by category
  discussions/<n>.md     the full thread: opening post, every comment, nested replies
  board-<name>.md        Projects v2 items grouped by status column
```

Index files are orientation layers, not mirrors: a 160-character preview per item, with full text in the detail file. That follows LifeOS decision 0002 and keeps `sources/` scannable.

**Discussions carry their full thread**, including nested replies rendered as blockquotes. That is deliberate and differs from how an issue is treated: an issue's substance is usually its title and body, while a discussion's substance *is* the argument in the replies. Truncating one would discard the thing worth having.

Detail directories are **rebuilt** on every sync, so an issue that closes stops appearing. Do not assume a file's presence means the item is still open — the index is the authority on what is open.

## When To Sync
Before reasoning about current state in any repo the vault tracks. A stale snapshot that reports closed issues as open is worse than no snapshot, and it is the failure mode most likely to embarrass you in front of other people.

## Boundaries
- Do not hand-edit anything under `sources/github/`. It is regenerated wholesale.
- Do not add a repo to the config just because it exists. Every entry costs sync time and snapshot size; add repos whose issue state the vault actually reasons about.
- Discussion fetching is bounded by GitHub's GraphQL node limit — 50 discussions, 50 comments each, 25 replies each. A thread past those caps is truncated and the detail file says so. The caps exist because 100/100/100 exceeds GitHub's 500,000-node ceiling and the whole query fails.
