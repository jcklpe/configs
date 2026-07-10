# LifeOS Code Cleanup To-Do
Status: **active.** Nothing refactored yet. Design settled in the conceptual doc; this tracks execution.

Conceptual doc: `docs/active-spikes/lifeos-code-cleanup.md`.

## Background
`configs/lifeos-tools/` is a working `lifeos` CLI dumped into one folder with no structure, fronted by a 2,550-line `lifeos.sh`. This spike reshapes it into a dispatcher-plus-libs application and organizes the folder, with zero behavior change. Design worked out in conversation on 2026-07-10.

## Project Organization
Rough target shape (names finalized while doing the work):

```text
lifeos-tools/
  lifeos            # thin wrapper, exec's lifeos.sh (unchanged)
  lifeos.sh         # thin dispatcher: bootstrap + top-level case, sources lib/
  lib/
    common.sh       # shared helpers: config/.env loading, output, _var_is, etc.
    trello.sh
    calendar.sh
    google.sh       # auth, accounts, drive, gmail, sheets, people
    open-austin-org.sh
    vault.sh
  python/           # google-*.py helpers, relocated from root
  skills/           # tool-operation skills seam (filled by the conversion spike)
  secrets/          # .env, *token*.json, *credentials*.json, *-accounts.json (all gitignored)
  qa/               # trello-qa.md, calendar-qa.md, open-austin-org-qa/ (all gitignored)
  tests/            # existing test harness (stays)
  .env.example, *.example.json  # tracked example files, beside their real counterparts
```

## General Principles
- Behavior is frozen. Same commands, flags, output. Verify against `tests/` and real invocations.
- Relocating a file and re-pointing its references happen in the same change, or the CLI breaks.
- After any secret-file move, confirm `.gitignore` still matches it. A de-ignored token is a leak.
- One commit does one coherent change; `Spike: lifeos-code-cleanup` on each.

## Current State Overview (2026-07-10, pre-refactor)
- `lifeos.sh`: 2,550 lines, `#!/usr/bin/env bash`. Top-level `case` dispatch begins ~line 2468, routing `doctor`, `trello`, `calendar`, `google`, `people`, `gmail`, `open-austin-org`, `sync` to `_<feature>_<action>` functions.
- Functions already cluster by feature: `_calendar_*` (~8), `_trello_*` (~14 across write/list/link/render/resolve/set), `_google_account(s)_*` (~8), `_drive_*` (5), `_open_austin_org_*` (3), `_gmail_*` (2), `_people_*` (4), `_vault_*` (2), plus shared helpers. These are the natural `lib/` seams.
- Root also holds: `google-*.py` (6 Python helpers), secret JSON tokens/credentials, `google-accounts.json`, `people-aliases.json`, QA artifacts (`calendar-qa.md`, `trello-qa.md`, `open-austin-org-qa/`), example files, `tests/`, `tmp/`, `__pycache__/`.
- `.gitignore` already correctly ignores secrets, caches, generated `sources/`, and QA artifacts. They are just physically in root, not in subfolders. So this spike relocates already-ignored files; it does not change what is ignored (only, possibly, the patterns if paths change).

## To Do
- [ ] Answer the bash-version question: grep `lifeos.sh` for bash-4-isms (`declare -A`, `${var,,}`, `mapfile`/`readarray`, `${var^^}`) and check whether the `lifeos` wrapper or install assumes Homebrew bash. Record the answer; it constrains the refactor.
- [ ] Map the secret/QA path coupling: grep `lifeos.sh` and `google-*.py` for every referenced filename (`.env`, `*token*.json`, `google-accounts.json`, `people-aliases.json`, the `*-qa` paths). List each reference so relocation can re-point them all.
- [ ] Confirm how `tests/` is run (harness, command, whether it hits the network) so it can serve as the refactor's regression check.
- [ ] Extract `common.sh`: config/`.env` loading, output/rendering helpers, and generic utilities. Source it first from `lifeos.sh`.
- [ ] Extract each feature module (`trello.sh`, `calendar.sh`, `google.sh`, `open-austin-org.sh`, `vault.sh`) from `lifeos.sh` into `lib/`, one feature per commit, running `tests/` after each.
- [ ] Reduce `lifeos.sh` to the dispatcher: bootstrap, `source lib/*.sh`, and the top-level `case`.
- [ ] Relocate the Python helpers into `python/` and re-point their invocations.
- [ ] Relocate secrets into `secrets/` and QA artifacts into `qa/`, re-pointing every path found in the coupling map, and updating `.gitignore` patterns to match the new locations. Verify `git status` shows no secret newly tracked.
- [ ] Settle the `skills/` seam: document the location decision in the conceptual doc / `AGENTS.md` if needed. Do not create an empty folder.
- [ ] Update `lifeos-tools/README.md` and `AGENT.md` if the reorganization changes any documented path or invocation.
- [ ] Full regression: run `tests/`, then exercise a real read-only command of each feature (e.g. `lifeos doctor`, `lifeos trello list-lists`) and confirm identical behavior.

## Ready for Human QA
- None yet. Likely QA items: live commands that write to Trello/Google or hit real APIs, which cannot be safely exercised from the terminal and need the user to run them on their machine with real secrets.

## Done
- None yet.

## Validation
No unit-test-style suite for the shell beyond `tests/`. Validate by:

- `bash -n lifeos.sh` and `bash -n lib/*.sh` after each extraction (syntax).
- Running `tests/` after each feature extraction.
- `lifeos doctor` and one read-only command per feature, before and after, confirming identical output.
- `git status --short` after secret/QA relocation — nothing secret newly tracked.

## Public Safety And Secrets
`lifeos-tools/` lives in the **public** configs repo. Real secrets live here but are gitignored. The single biggest risk in this spike is a relocation that moves a secret file out from under its `.gitignore` pattern and into a tracked path. Every secret move must be followed by a `git status` check and, ideally, a `git check-ignore` on the new path. See `docs/decisions/0001-secrets-and-local-env.md`.
