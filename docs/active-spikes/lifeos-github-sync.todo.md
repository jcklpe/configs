# LifeOS GitHub Sync — To Do
## Background
Generalize GitHub syncing out of the Open-Austin-only adapter into a `lifeos github` command group covering issues, PRs, discussions, and boards for any configured repo. Conceptual doc: `docs/active-spikes/lifeos-github-sync.md`.

## Project Organization
- Implementation: new `lifeos-tools/lib/github.sh`, following the shape of `lib/trello.sh` and `lib/google.sh`.
- Dispatch: `lifeos-tools/lifeos.sh`, a new `github)` case beside the existing `open-austin-org)`.
- Config: a new gitignored `secrets/github-repos.json` plus its `.example.json`, following `google-accounts.json`.
- Prior art to port: `~/work/org/tools/sync/{issues,boards,labels}.py`, `run.sh`.
- Docs: a new `lifeos-tools/skills/lifeos-github/SKILL.md`, plus a pointer from `lifeos-cli`.
- Tests: offline and fixture-driven, following `tests/test-trello-renderers.sh`.
- Run the suite: `cd lifeos-tools && for test in tests/test-*.sh; do bash "$test" || exit; done`

## General Principles
- bash 3.2 safe. No associative arrays, no `readlink -f`.
- Snapshots are read-only context. Never edit a generated file to change GitHub state.
- Writes are dry-run by default and fail rather than guess.
- Tests never hit the network.

## Current State Overview
- Nothing implemented. Spike opened 2026-09-07.
- Verified 2026-09-07: `gh` is already authorized for both `open-austin` and `Agentic-Collaborative-Wiki-HAI`. The HAI repo has issues and discussions enabled, 18 open issues, 5 discussions.
- Verified 2026-09-07: discussions are not reachable through `gh issue`/REST; the GraphQL query works.

## To Do
- [ ] Decide the snapshot layout under `sources/github/`. Aslan specified `sources/github/` as the destination; per-repo subdirectory naming is still open.
- [ ] Define the repo config file shape and write the `.example.json`.
- [ ] Port issue sync, including full comment threads, from `tools/sync/issues.py`.
- [ ] Add PR sync. No prior art — this is new.
- [ ] Add discussion sync via GraphQL. No prior art — this is new.
- [ ] Port board sync from `tools/sync/boards.py` (Projects v2).
- [ ] Decide whether label sync survives the port or is dropped as org-specific.
- [ ] Carry over the issue and board write paths the vault needs, dry-run by default.
- [ ] Wire `github)` into the dispatcher and the usage block.
- [ ] Write `lifeos-tools/skills/lifeos-github/SKILL.md` and register it in `install-script/functions/symlinks.sh` for both hosts.
- [ ] Add offline renderer tests with fixtures.
- [ ] Run the full suite and `bash -n` both changed shell files.
- [ ] Confirm whether `open-austin-org` becomes a thin alias over the generic path or stays as-is. **Open question — see below.**

## Open Questions
- **Does the generic tool eventually absorb `open-austin/org`, or does that adapter stay?** Aslan has not ruled. Absorbing it means one code path and one skill; keeping both means two sync paths forever but a smaller blast radius when changing either.
- Whether HAI project context lives at `grad-school/courses/human-ai-interaction-inf-385t-13/agentic-wiki-project/` as the working home while the GitHub snapshot lands in `sources/github/`. Aslan specified both paths; confirming they are the two halves rather than alternatives.

## Ready for Human QA
- (none yet)

## Done
- (none yet)
