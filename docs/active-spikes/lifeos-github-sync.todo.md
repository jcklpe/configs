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
- [ ] Carry over the issue and board write paths the vault needs, dry-run by default. **Not started** — sync is read-only today.
- [ ] Delete the `open-austin-org` adapter (`lib/open-austin-org.sh`, its dispatch case, usage lines, the `lifeos-open-austin` skill) and retire `sources/open-austin-org/` in the vault, now that `sources/github/open-austin-org/` supersedes it.
- [ ] Decide whether `tools/issues/create.sh` from the org repo becomes `lifeos github create-issue` here. See Open Questions.
- [ ] Decide whether the vault should still receive Open Austin weekly summaries, and in what shape. **This is a LifeOS-side call, tracked in the LifeOS spike.**

## Done
- [x] Decide the snapshot layout under `sources/github/`. — `sources/github/<owner>-<repo>/` holding `issues.md` + `issues/<n>.md`, `pull-requests.md` + `pull-requests/<n>.md`, `discussions.md`, and `board-<name>.md`. Flat owner-repo slug rather than nested, so one `ls` shows every tracked repo.
- [x] Define the repo config file shape and write the `.example.json`. — `secrets/github-repos.json`, gitignored, following the `google-accounts.json` pattern. Per-repo booleans for issues/prs/discussions plus a `projects` list. No token in it; auth is `gh`.
- [x] Port issue sync, including full comment threads, from `tools/sync/issues.py`. — Ported into `lib/github-render.py` with two changes: detail directories are rebuilt each sync (the original accumulated stale files — 99 against 72 open issues), and an empty index is skipped entirely rather than written as a zero-count file.
- [x] Add PR sync. No prior art — this is new. — Shares the issue code path, since the shapes match; `--kind` switches the labels so a PR index is never rendered as issues. A negative test guards that.
- [x] Add discussion sync via GraphQL. No prior art — this is new. — `gh api graphql`, grouped by category, with author, comment count, and answered state. REST genuinely cannot see discussions, which is why they were invisible before.
- [x] Port board sync from `tools/sync/boards.py` (Projects v2). — `gh project item-list`, grouped by status column. Verified against Org Kanban (88 items) and Open Roles (19).
- [x] Decide whether label sync survives the port. — **Dropped.** It existed to support the team-label routing table in `weekly-org-summary`, which stays in the org repo, and the live taxonomy is visible in the GitHub UI or `gh label list`. Nothing in the vault reasons about it.
- [x] Wire `github)` into the dispatcher and the usage block.
- [x] Write `lifeos-tools/skills/lifeos-github/SKILL.md` and register it in `install-script/functions/symlinks.sh` for both hosts. — Both lines added; live symlinks created by hand so the skill works now.
- [x] Add offline renderer tests with fixtures. — 21 assertions over 4 fixtures. Caught a bad fixture on first run: the truncation marker sat inside the 160-char preview window, so the test would have passed for the wrong reason.
- [x] Run the full suite and `bash -n` both changed shell files. — All 9 test files pass.
- [x] Unplanned: `lifeos-tools/qa/` was not gitignored and now holds real synced org data. Added `**/qa/` to `.gitignore`.

## Open Questions
- **Resolved 2026-09-07: the generic tool absorbs `open-austin/org` and the adapter is deleted.** The org repo keeps its own `tools/sync/` because `weekly-org-summary` depends on it. Two separate consumers of the same public API, neither importing the other — not duplication to keep in step.
- **Resolved 2026-09-07:** HAI working context at `grad-school/courses/human-ai-interaction-inf-385t-13/agentic-wiki-project/`, generated snapshot at `sources/github/`. Two halves, not alternatives. Confirmed by Aslan.
- Still open: whether label sync survives the port. It exists in the org tooling to support the team-label routing table in `weekly-org-summary`, which stays in the org repo. The vault may not need it at all.

## Ready for Human QA
- (none yet)

## Done
- (none yet)
