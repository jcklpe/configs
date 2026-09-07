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

## Sequencing Constraint
**Build here first, then rip out there.** Removing `tools/sync/` before the generic tool works leaves a window with no working org sync at all. The org-side removal is a successor spike, not part of this one.

Continues in: the org-repo removal spike (to be opened in `~/work/org/docs/active-spikes/` once this ships)

## Design Notes Carried Forward
- **Discussions need GraphQL.** Issues, PRs, and board items are reachable through `gh` and REST; discussions are GraphQL-only. Verified 2026-09-07 against the HAI repo.
- **Board sync comes along.** Aslan's call: the vault needs issue context *and* board context, plus whatever writes those require. So `boards.py`'s Projects v2 reading is in scope here, not left behind.
- **Repo list is configuration, not code.** Follow the existing alias pattern (`google-accounts.json`, `m365-accounts.json`) rather than hardcoding.
- **Existing prior art is 463 lines** across `~/work/org/tools/sync/{issues,boards,labels}.py` and `run.sh`. Port and generalize rather than rewrite from scratch; the issue-with-full-comment-threads rendering is already solved there.
- Writes stay dry-run-by-default and follow `docs/decisions/0006-writes-fail-rather-than-guess.md`.

## Downstream Work This Unblocks
The vault's `open-austin-github` skill describes the current adapter and public/private boundary. It needs substantial rewriting once this lands, and it is the reason the LifeOS skill-renaming pass should not touch that skill in isolation.
