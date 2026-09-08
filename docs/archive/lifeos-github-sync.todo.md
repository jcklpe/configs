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
- (none)

## Done
- [x] Carry over the issue and board write paths the vault needs, dry-run by default. — **Done.** `create-issue` (alias or literal OWNER/REPO) and `move-card` (Projects v2 status field, unknown columns list the valid ones). Both dry-run by default.
- [x] Delete the `open-austin-org` adapter. — Done, along with the `lifeos-open-austin` skill and the vault's `sources/open-austin-org/`. Removed the last cross-repo dependency in either direction.
- [x] Decide whether `tools/issues/create.sh` moves here. — **Yes**, and the org copy was removed. Aslan initially suggested `configs/skills/`; the argument against was that this spike exists to stop GitHub work being split across two homes, and splitting reads from writes recreates that.
- [x] Decide whether the vault should still receive Open Austin weekly summaries. — **No; retired.** The org repo keeps its skill as a reimplementation record.
- [x] Unplanned: reversed the decision against board writes. I argued they would fight the automation — "card moves, workflow moves it back." That was factually wrong, and open-austin/org's decision 0005 says so: card→close is native Auto-close, card→reopen is a cron reconciler, and both are designed inputs. I had also conflated a policy question (agents need approval) with a design one (the capability should not exist).
- [x] Unplanned: discussions carry full threads rather than previews, at Aslan's direction. An issue's substance is its title and body; a discussion's substance is the argument in the replies.
- [x] Unplanned: hit GitHub's GraphQL 500,000-node ceiling at 50×100×100 discussions/comments/replies. Capped at 50/50/25. **The error was invisible** — the handler warned "may be disabled" and swallowed stderr, so a hard query failure looked like a repo with discussions turned off. Same class as the calendar time zone silently defaulting to UTC.

## Open Questions
- **Resolved 2026-09-07: the generic tool absorbs `open-austin/org` and the adapter is deleted.** The org repo keeps its own `tools/sync/` because `weekly-org-summary` depends on it. Two separate consumers of the same public API, neither importing the other — not duplication to keep in step.
- **Resolved 2026-09-07:** HAI working context at `grad-school/courses/human-ai-interaction-inf-385t-13/agentic-wiki-project/`, generated snapshot at `sources/github/`. Two halves, not alternatives. Confirmed by Aslan.
- Still open: whether label sync survives the port. It exists in the org tooling to support the team-label routing table in `weekly-org-summary`, which stays in the org repo. The vault may not need it at all.

## Ready for Human QA
- (none yet)

## Done
- (none yet)
