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
  lib/              # the implementation library, language-agnostic
    common.sh       # shared helpers: config/.env loading, output, _var_is, etc.
    trello.sh
    calendar.sh
    google.sh       # auth, accounts, drive, gmail, sheets, people
    open-austin-org.sh
    vault.sh
    google-calendar-render.py   # Python helpers live here too — organized by
    google-calendar-write.py    # purpose, not language. lib/*.sh is sourced;
    google-calendar-auth.py     # the .py files are invoked by path.
    google-gmail-render.py
    google-sheets-render.py
    google-people.py
    google-oauth.py
  skills/           # tool-operation skills seam (filled by the conversion spike)
  secrets/          # .env, *token*.json, *credentials*.json, *-accounts.json (already ignored at any depth)
  qa/               # trello-qa.md, calendar-qa.md, open-austin-org-qa/ (already ignored at any depth)
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

**Investigation complete (2026-07-10), baseline green.** bash 3.2 confirmed as the only interpreter; assets are uniformly `SCRIPT_DIR`-anchored; both `tests/` pass offline. Details in Done. The plan is now risk-ordered: modularize first (safe), move Python helpers next (contained, touches tests), treat secrets/QA relocation as a deliberate decision gate rather than a given.

## To Do
- [ ] Centralize asset locations as named variables in the bootstrap (`PYTHON_DIR`, and later `SECRETS_DIR`/`QA_DIR`), extending the existing `ENV_FILE` pattern, so relocations become one-line definition changes instead of call-site hunts.
- [ ] Extract `common.sh`: config/`.env` loading, output/rendering helpers, and generic utilities. Source it first from `lifeos.sh`. Keep `SCRIPT_DIR` defined in `lifeos.sh` (not recomputed in the lib).
- [ ] Extract each feature module (`trello.sh`, `calendar.sh`, `google.sh`, `open-austin-org.sh`, `vault.sh`) from `lifeos.sh` into `lib/`, one feature per commit, running `tests/` after each.
- [ ] Reduce `lifeos.sh` to the dispatcher: bootstrap, `source lib/*.sh`, and the top-level `case`.
- [ ] Move the Python helpers into `lib/` (not a separate `python/` folder — language-agnostic library) and re-point their invocations: **7 sites in `lifeos.sh` and 4 in `tests/`** (`test-calendar-render.sh`, `test-google-renderers.sh` both call `${TOOL_DIR}/google-*.py`). Run the tests after.
- [ ] Relocate secrets into `secrets/` and QA artifacts into `qa/`, re-pointing every `SCRIPT_DIR`-anchored reference. **No `.gitignore` change needed** — the patterns are filename-based and follow the files (verified); still run `git status` afterward as a sanity check. Cosmetic tidiness, no leak risk.
- [ ] Settle the `skills/` seam: document the location decision in the conceptual doc / `AGENTS.md` if needed. Do not create an empty folder.
- [ ] Update `lifeos-tools/README.md` and `AGENT.md` if the reorganization changes any documented path or invocation.
- [ ] Full regression: run `tests/`, then exercise a real read-only command of each feature (e.g. `lifeos doctor`, `lifeos trello list-lists`) and confirm identical behavior.

## Ready for Human QA
- None yet. Likely QA items: live commands that write to Trello/Google or hit real APIs, which cannot be safely exercised from the terminal and need the user to run them on their machine with real secrets.

## Done
- [x] **Answer the bash-version question: grep `lifeos.sh` for bash-4-isms (`declare -A`, `${var,,}`, `mapfile`/`readarray`, `${var^^}`) and check whether the `lifeos` wrapper or install assumes Homebrew bash. Record the answer; it constrains the refactor.** Answered 2026-07-10: **bash 3.2 only.** Zero bash-4 features (`declare/local -A`: 0, `${x,,}`/`${x^^}`: 0, `mapfile`/`readarray`: 0, `|&`: 0, `&>`: 0, `${!indirect}`: 0). No Homebrew bash is installed — `command -v bash` → `/bin/bash`, which is `GNU bash 3.2.57(1) arm64-apple-darwin24`. `env bash` therefore runs 3.2. The refactor must stay 3.2-safe; folded into the conceptual doc's Constraints.

- [x] **Map the secret/QA path coupling: grep `lifeos.sh` and `google-*.py` for every referenced filename. List each reference so relocation can re-point them all.** Done. Everything is `${SCRIPT_DIR}/<file>`-anchored. Counts in `lifeos.sh`: 7 `python3 ${SCRIPT_DIR}/*.py`, 7 `.env`/`ENV_FILE`, 8 `*-qa` (md + dir), 6 accounts/credentials JSON. `SCRIPT_DIR` is set at line 5 from `BASH_SOURCE`, `ENV_FILE` at line 7, and vault paths come from `LIFEOS_VAULT_PATH` (which correctly refuses to point inside the configs repo, line 163). The Python helpers are invoked at lines 949/953/1012/1016/1125/1222/1549. **The `tests/` also reference the helpers** (`${TOOL_DIR}/google-*.py`, 4 sites) — so a `python/` move touches the tests too. This surfaced the risk gradient now recorded in the conceptual doc's "Sequencing By Risk."

- [x] **Confirm how `tests/` is run (harness, command, whether it hits the network) so it can serve as the refactor's regression check.** Done. Two shell tests: `test-calendar-render.sh` and `test-google-renderers.sh`, each `bash tests/test-*.sh`, `set -eu`, asserting on rendered Markdown from JSON fixtures in `tests/fixtures/`. **Fully offline** — no network, no secrets, fixture-driven. **Both PASS on current code** (baseline green, 2026-07-10). `bash -n lifeos.sh` is clean under 3.2. These are the regression harness; run after each extraction.

## Validation
No unit-test-style suite for the shell beyond `tests/`. Validate by:

- `bash -n lifeos.sh` and `bash -n lib/*.sh` after each extraction (syntax).
- Running `tests/` after each feature extraction.
- `lifeos doctor` and one read-only command per feature, before and after, confirming identical output.
- `git status --short` after secret/QA relocation — nothing secret newly tracked.

## Public Safety And Secrets
`lifeos-tools/` lives in the **public** configs repo. Real secrets live here but are gitignored. Relocating them is **safe**: the `.gitignore` patterns are filename-based (`.env`, `*token*.json`, `*credentials*.json`, `google-accounts.json`), so they match at any depth — verified 2026-07-10 that `secrets/.env`, `secrets/google-token.json`, and `secrets/google-credentials.json` all stay ignored, while `secrets/.env.example` stays tracked. No gitignore change is required to move secrets into `secrets/`. Run `git status` after the move as a cheap confirmation. See `docs/decisions/0001-secrets-and-local-env.md`.
