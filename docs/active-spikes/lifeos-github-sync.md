# LifeOS GitHub Sync
## Why This Exists
`lifeos` can sync Trello, Calendar, Gmail, Drive, and M365, but its only GitHub capability is `open-austin-org`, a thin adapter that shells out to a *different repo's* tooling (`~/work/org/tools/sync/`) and copies the results into the vault. That was correct when Open Austin was the only GitHub project. It no longer is.

The HAI term project (`Agentic-Collaborative-Wiki-HAI/mono-repo`) has 18 open issues and 5 discussions carrying live architecture decisions, and none of it reaches the vault. An agent working in LifeOS is blind to it.

## Goals
Sync **issues, pull requests, discussions, and project boards** for an arbitrary configured set of repos into `sources/github/<owner>-<repo>/`, and carry the write capability the vault needs for issues and boards.

## Non-Goals
- Not a GitHub client. Bounded snapshots for agent context, the same contract as every other `lifeos` source.
- Not a replacement for `gh`. Ad-hoc work keeps using `gh` directly.
- Not cloning or indexing whole repos. Issues, PRs, discussions, and boards only.

## The Boundary Being Settled
This spike **moves a capability out of a public shared repo into private personal tooling**, which is the reverse of the usual direction and needs stating plainly.

The reasoning, from Aslan (2026-09-07):

- **Nobody else uses it.** The sync tooling in `~/work/org` has had one user since it was built. A tool with one user living in a shared repo is a personal tool with extra steps.
- **It does not generalize to collaborators.** The snapshots exist to feed a personal LifeOS vault. An Open Austin volunteer without one would just use the GitHub UI.
- **It is attack surface and dual maintenance.** `tools/google-docs/` in that repo carries OAuth credential paths and a documented write scope. Removing tooling nobody uses strictly reduces what a contributor can misconfigure, and stops Aslan maintaining two copies of one idea.

Rejected alternatives, and why:

- **Git submodule into both repos** — gives collaborators a pointer to a repo they cannot use, plus submodule maintenance, for no benefit.
- **Re-provisioning via `setup-local-skills`** — recreates the dual-maintenance problem the move exists to solve, for people who have not asked.
- **A link reference in the org repo** — considered and explicitly declined by Aslan. The org repo should carry no reference to the private tooling at all, matching the precedent set by `docs/decisions/0005`, where `lifeos docs` was ported out of the org repo and the org repo was left with no `lifeos` mention.

## Correction 2026-09-07: The Org-Side Rip-Out Is Mostly Cancelled
The original plan had a successor spike removing `tools/sync/` from `~/work/org`. **Investigation says do not do that**, and the evidence is direct.

`~/work/org/skills/weekly-org-summary/SKILL.md` **step 1 is literally `tools/sync/run.sh`**, and steps 2 onward read `snapshot/issues.md`, `snapshot/labels.md`, and `snapshot/issues/*.md`. The weekly summary — the genuinely collaborative capability, the one that posts to seven Open Austin team Slack channels — *is built on the sync tooling*. Removing `tools/sync/` breaks it.

So the premise that started this ("nobody else uses the sync tooling") was true about one thing and false about another. Nobody else drives it into a LifeOS vault. But it is the input stage of a shared workflow any contributor should be able to run, which makes it org infrastructure rather than personal tooling that happens to live in a shared repo.

**The resulting design is better than the one it replaces.** Instead of moving code between repos:

- The generic `lifeos github` tool **syncs `open-austin/org` directly from the GitHub API**, exactly as it will sync every other repo.
- `~/work/org` **keeps `tools/sync/` unchanged**, for `weekly-org-summary` and any contributor who wants a local snapshot.
- The `open-austin-org` adapter in this repo **is deleted**, because nothing needs it once the generic path exists.

That is one code path in each repo, no duplication to keep in step, and — the actual win — **the vault stops reaching into a sibling checkout to sync itself.** Today `lifeos open-austin-org sync` fails outright if `~/work/org` is missing or its `run.sh` is not executable. After this, syncing Open Austin needs only `gh` auth.

The org repo therefore needs **no removal at all**: not `tools/sync/`, not `tools/notify/`, not the PAT setup section (the weekly summary needs `gh` auth too), not `tools/issues/create.sh`. The org-side spike is cancelled pending Aslan's agreement.

## Also Found: The Adapter Ferries A Hand-Authored File
`_copy_open_austin_org_snapshot` copies `weekly-summary.md`, which `tools/sync/run.sh` **does not generate**. It is agent-authored via `weekly-org-summary` and rendered to Slack by `tools/notify/`. So the adapter has been doing two unrelated jobs — syncing generated GitHub state, and ferrying a hand-written summary into the vault.

Worse, it copies only the legacy combined `weekly-summary.md` while the snapshot now holds seven per-team files (`weekly-summary-board.md`, `-communications.md`, `-engagement.md`, `-finance.md`, `-fundraising.md`, `-infrastructure.md`, `-org.md`) from the weekly-summary-channels work. **The vault has been receiving a stale artifact shape.**

Deleting the adapter removes the ferry too, so decide deliberately whether the vault should still receive weekly summaries and in what shape. That is a LifeOS-side question, not a GitHub-sync one.

## Board Sync Is Read-Only, And That Matters For Scope
Verified: every `gh` call in `tools/sync` is a read — `issue list`, `label list`, `project item-list`, `api`. There are no writes anywhere in it.

Board *automation* is a completely separate system: **thirteen GitHub Actions workflows** in `~/work/org/.github/workflows/` (`add-issue-to-kanban`, `board-reopen-reconcile`, `close-to-done`, `stale-role-warning`, and the rest). Those are org-specific governance, they stay put, and nothing here touches them.

So "board sync" in this spike means **reading board state into local context**, nothing more.

## Design Notes Carried Forward
- **Discussions need GraphQL.** Issues, PRs, and board items are reachable through `gh` and REST; discussions are GraphQL-only. Verified 2026-09-07 against the HAI repo.
- **Board sync comes along.** Aslan's call: the vault needs issue context *and* board context, plus whatever writes those require. So `boards.py`'s Projects v2 reading is in scope here, not left behind.
- **Repo list is configuration, not code.** Follow the existing alias pattern (`google-accounts.json`, `m365-accounts.json`) rather than hardcoding.
- **Existing prior art is 463 lines** across `~/work/org/tools/sync/{issues,boards,labels}.py` and `run.sh`. Port and generalize rather than rewrite from scratch; the issue-with-full-comment-threads rendering is already solved there.
- Writes stay dry-run-by-default and follow `docs/decisions/0006-writes-fail-rather-than-guess.md`.

## Downstream Work This Unblocks
The vault's `open-austin-github` skill describes the current adapter and public/private boundary. It needs substantial rewriting once this lands, and it is the reason the LifeOS skill-renaming pass should not touch that skill in isolation.
