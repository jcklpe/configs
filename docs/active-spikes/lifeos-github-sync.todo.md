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
- **The org-side rip-out was investigated and cancelled the same day.** `skills/weekly-org-summary/SKILL.md` step 1 is `tools/sync/run.sh`; removing the sync tooling would break the weekly Slack summary. Full reasoning in the conceptual doc.
- Verified 2026-09-07: `tools/sync` contains no writes. Board automation is thirteen separate GitHub Actions workflows in `.github/workflows/` and is out of scope entirely.
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
- [ ] Delete the `open-austin-org` adapter (`lib/open-austin-org.sh`, its dispatch case, usage lines, and the `lifeos-open-austin` skill) once the generic path syncs `open-austin/org`. **Resolved 2026-09-07 — see the conceptual doc.** The adapter is 100 lines of shell-out-and-copy and nothing needs it once the generic tool talks to the GitHub API directly.
- [ ] Decide whether the vault should still receive Open Austin weekly summaries, and in what shape. The adapter currently ferries the legacy combined `weekly-summary.md`, which sync does not generate and which has been superseded by seven per-team files. Deleting the adapter removes the ferry. **This is a LifeOS-side call, tracked in the LifeOS spike.**

## Open Questions
- **Resolved 2026-09-07: the generic tool absorbs `open-austin/org` and the adapter is deleted.** The org repo keeps its own `tools/sync/` because `weekly-org-summary` depends on it. Two separate consumers of the same public API, neither importing the other — not duplication to keep in step.
- **Resolved 2026-09-07:** HAI working context at `grad-school/courses/human-ai-interaction-inf-385t-13/agentic-wiki-project/`, generated snapshot at `sources/github/`. Two halves, not alternatives. Confirmed by Aslan.
- Still open: whether label sync survives the port. It exists in the org tooling to support the team-label routing table in `weekly-org-summary`, which stays in the org repo. The vault may not need it at all.

## Ready for Human QA
- (none yet)

## Done
- (none yet)
