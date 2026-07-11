# LifeOS Code Cleanup
Status: **archived 2026-07-11.** Opened 2026-07-10. Reorganized `configs/lifeos-tools/` and modularized `lifeos.sh` (2,550 → 324 lines) into a dispatcher plus `lib/` modules, moved the Python helpers into `lib/`, and relocated secrets and QA output into `secrets/` and `qa/`. Behavior unchanged throughout, verified against a golden baseline. This doc is historical context, not current rules.

Companion to-do: `docs/archive/lifeos-code-cleanup.todo.md`.

This is one of three sibling spikes from the same design conversation. The others are LifeOS Handoff (a global skill for feeding progress to the LifeOS vault) and Vault Runbook Conversion (turning the vault's runbooks into skills). This spike is a prerequisite for the conversion: it establishes the `lifeos-tools/skills/` folder that the conversion later fills with tool-operation skills.

## Purpose
`lifeos-tools/` is a working CLI that has grown into a junk drawer. `lifeos.sh` is a single 2,550-line bash file, and the folder root mixes that file with Python helpers, secret tokens, QA artifacts, and example files, with no structure. The tool works; it is just unpleasant to read, extend, and reason about.

This spike makes the folder pleasant to work in. It changes *shape*, never *behavior*.

## Goals
- Split `lifeos.sh` into a thin dispatcher plus feature libraries.
- Give the folder real structure: homes for secrets, QA artifacts, and Python helpers, instead of dumping everything in root.
- Establish the `lifeos-tools/skills/` seam where tool-operation skills will live (populated by the Vault Runbook Conversion spike, not here).
- Leave the `lifeos` CLI behaving exactly as it does today, verified against the existing `tests/`.

## Non-Goals
- **Not the `skills/scripts/` format.** See "Why Not Skills-First" below. This was decided deliberately, not skipped.
- **No MCP.** Deferred indefinitely; it is ergonomic-only for the local agents that can already run the CLI, and cannot cleanly reach the sandboxed Cowork agent given its no-external-secrets posture.
- **No behavior or capability change.** Same commands, same flags, same output. A pure refactor.
- **No language rewrite.** It stays bash + the existing Python helpers.
- **Do not touch the vault.** Vault-side work belongs to the conversion spike.
- **No new secrets handling.** `.gitignore` already covers secrets and QA artifacts correctly; this spike only relocates files physically, and must keep them ignored.

## The Settled Model: Organize As An Application
The CLI is a *cohesive application*, not a bag of independent scripts: a dispatcher routes subcommands to `_<feature>_<action>` functions, and heavy shared infrastructure (Google OAuth used across calendar/gmail/sheets/people, `.env`/config loading, output rendering) is reused across features. So it should be organized the way applications are:

- `lifeos.sh` shrinks to a **thin dispatcher** — the top-level `case` block plus bootstrap — that sources the libs.
- `lib/` holds **feature modules**, split along the seams the functions already follow: `trello`, `calendar`, `google` (auth/accounts/drive/gmail/sheets/people), `open-austin-org`, `vault`, and a `common` module for the genuinely shared helpers.
- The **Python helpers (`google-*.py`) also live in `lib/`**, as library code that happens to be Python. Organize by what they are — feature implementation — not by language. `lib/*.sh` is sourced; the `.py` files are invoked by path; the filenames keep the distinction obvious. A separate `python/` or `helpers/` folder would be a format-first split, the same mistake as organizing by skill format.
- Secrets and QA artifacts get subfolders (`secrets/`, `qa/`), out of the root. The `.gitignore` patterns are filename-based and follow the files into any subfolder (verified), so this is a purely cosmetic move with no leak risk and no gitignore change required.

The exact folder names are a to-do detail, settled while doing the work.

## Why Not Skills-First
A `skills/<capability>/scripts/` layout — the skill as the top-level unit, code nested under it — is good for a *toolbox of independent, self-contained scripts meant to be read-and-run by a sandboxed agent*. It is wrong for this tool, for two reasons.

First, the tool is cohesive, not independent. Its shared infrastructure (Google auth, config loading, rendering) belongs to no single capability, so a skills-first layout forces a shared `lib/` anyway — you end up with skill folders *plus* horizontal layering, which is more structure, not less.

Second, and decisively: the whole payoff of skills-with-bundled-scripts is a sandboxed agent reading a skill and running its script. The sandboxed agent here (Cowork) *cannot run these scripts* — blocked by secrets and allowlisted network, regardless of layout — and the local agents invoke `lifeos <cmd>` through the dispatcher, never reading individual scripts. The consumer the pattern optimizes for does not exist in this context.

The feature cohesion that skills-first offers is obtained instead from feature-named `lib/` modules, with no coupling of code to the docs taxonomy.

**Code and guidance stay separate layers.** Modular code lives in `lifeos-tools/` (dispatcher + `lib/`); thin tool-operation *skills* live beside it in `lifeos-tools/skills/` and describe how to drive the CLI. They do not nest.

## Constraints
- **Do not break the CLI.** It is a live tool the user depends on. The `tests/` folder holds two renderer tests; both pass on current code (verified 2026-07-10) and run offline against fixtures. They are the regression harness — keep them green, and spot-check behavior against real invocations.
- **Bash 3.2 only.** Confirmed 2026-07-10: `lifeos.sh` uses zero bash-4 features, and no Homebrew bash is installed, so `env bash` resolves to macOS system bash 3.2.57. The refactor must stay 3.2-safe — no associative arrays, no `${var,,}`/`${var^^}`, no `mapfile`/`readarray`, no `&>`, no `${!indirect}`.
- **Everything is `SCRIPT_DIR`-anchored, and that is the coupling to manage.** Assets are referenced as `${SCRIPT_DIR}/<file>`: the Python helpers (7 call sites), `.env`/`.env.example` (7), QA artifacts (8), account/credential JSON (6). The `tests/` also invoke the Python helpers by path (`${TOOL_DIR}/google-*.py`, 4 sites). So relocating any asset means re-pointing every reference across both `lifeos.sh` and `tests/`, together, or the CLI breaks. The clean technique is to centralize each asset location as a named variable in the bootstrap (the code already does this for `ENV_FILE`), so a move becomes one definition change rather than a call-site hunt.
- **`SCRIPT_DIR` must stay defined once, in `lifeos.sh`, and be inherited by the sourced libs.** It is derived from `lifeos.sh`'s own `BASH_SOURCE`, so it points at the `lifeos-tools/` root. A `lib/` module must *not* recompute its own directory for asset paths — that would resolve to `lib/` and break everything.
- **Secrets stay ignored automatically.** Verified 2026-07-10: the `.gitignore` patterns are filename-based (`.env`, `*token*.json`, `*credentials*.json`, `google-accounts.json`), so they match at any depth — a secret moved into `secrets/` stays ignored, and the `!*.example` negations keep the example templates tracked. No gitignore change is needed to relocate secrets. Still run `git status` after the move as a cheap sanity check, but the earlier "de-ignoring a token" worry was unfounded.

## The Skills Seam
"Establish the seam" means **decide and document** that tool-operation skills live at `lifeos-tools/skills/<name>/SKILL.md`, symlinked into `~/.claude/skills/` and `~/.codex/skills/` for global availability to local agents. It does *not* necessarily mean creating an empty folder now — git does not track empty folders, and the first real tool skill arrives in the conversion spike. The deliverable here is the decision and the documented location, so the conversion spike has a stable target.

## Relationship To Other Spikes
Sibling to `docs/active-spikes/lifeos-handoff.md` (not yet created) and predecessor to `docs/active-spikes/vault-runbook-conversion.md` (not yet created). The conversion depends on this spike having settled where tool skills live. Formal `Continues in:` markers get added when those docs exist.

## Sequencing By Risk (from the investigation)
The investigation, plus the correction that gitignore is relocation-safe, gives this order. Every step is mechanical; the only real hazard is re-pointing `SCRIPT_DIR` references, which the named-variable technique defuses.

1. **Modularize `lifeos.sh` into `lib/`** — the core. `SCRIPT_DIR` stays at the root, no assets move, behavior is identical. First.
2. **Move the Python helpers into `lib/`** — re-points 7 references in `lifeos.sh` and 4 in `tests/`. Contained; run the tests after.
3. **Relocate QA artifacts (`qa/`)** — self-contained: the QA output paths are hardcoded to `${SCRIPT_DIR}`, gitignore follows the files by name, so this is re-point-five-references-and-ensure-the-dir. Low value, low risk.
4. **Relocate secrets (`secrets/`)** — *not* self-contained, discovered during execution. The credential/token/accounts/aliases paths are set in the **user's private `.env`** (`GOOGLE_CALENDAR_CREDENTIALS_PATH="$CONFIGS/lifeos-tools/google-credentials.json"`, etc.), which is gitignored and cannot be edited from the repo. Moving the files would require the user to update their `.env` by hand, and until they do, the tool breaks at runtime (`doctor` reports "credentials file does not exist"). So this is a user decision, not a mechanical step — the gitignore is relocation-safe, but the `.env` coupling is not. Recommendation: leave secrets in root (already gitignored, so the committed repo is already clean; only a local `ls` sees them), since the cost is real and the gain is cosmetic.

## Open Questions
- Should the Python helpers merely relocate into `lib/`, or get light cleanup while being moved? Default: relocate only, keep this a pure structural refactor; note any Python smells for a later pass rather than fixing them here.
