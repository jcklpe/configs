# LifeOS Code Cleanup
Status: **active spike.** Opened 2026-07-10. Reorganize `configs/lifeos-tools/` and modularize the 2,550-line `lifeos.sh` on maintainability grounds. No behavior change, no new capabilities.

Companion to-do: `docs/active-spikes/lifeos-code-cleanup.todo.md`.

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
- Python helpers (`google-*.py`) move into their own home rather than sitting in root.
- Secrets and QA artifacts get subfolders, out of the root.

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
- **Secrets stay ignored.** After any secret move, confirm the relocated file is still matched by `.gitignore` (`git check-ignore` on the new path) and that `git status` shows nothing newly tracked. A relocation that de-ignores a token is a leak into a public repo.

## The Skills Seam
"Establish the seam" means **decide and document** that tool-operation skills live at `lifeos-tools/skills/<name>/SKILL.md`, symlinked into `~/.claude/skills/` and `~/.codex/skills/` for global availability to local agents. It does *not* necessarily mean creating an empty folder now — git does not track empty folders, and the first real tool skill arrives in the conversion spike. The deliverable here is the decision and the documented location, so the conversion spike has a stable target.

## Relationship To Other Spikes
Sibling to `docs/active-spikes/lifeos-handoff.md` (not yet created) and predecessor to `docs/active-spikes/vault-runbook-conversion.md` (not yet created). The conversion depends on this spike having settled where tool skills live. Formal `Continues in:` markers get added when those docs exist.

## Sequencing By Risk (from the investigation)
The investigation revealed a clear risk gradient, and the work should follow it:

1. **Modularize `lifeos.sh` into `lib/`** — low risk, high value. `SCRIPT_DIR` stays at the root, no assets move, behavior is identical. This is the core of the spike and comes first.
2. **Relocate the Python helpers into `python/`** — contained. No secrets, no `.gitignore` involvement, but it touches 7 references in `lifeos.sh` *and* 4 in `tests/`. Do it as one careful change with a full test run.
3. **Relocate QA artifacts and secrets** — the delicate tail, and a genuine judgment call (see open question). Highest risk, lowest value.

## Open Questions
- **Is relocating secrets and QA artifacts into subfolders worth the risk at all?** They are already gitignored, so root clutter is the *only* cost of leaving them. Relocating them carries real downside: a secret moved out from under its ignore pattern is a leak, and it re-points many `SCRIPT_DIR`-anchored references. Modularizing `lifeos.sh` and moving the Python helpers are clearly worth it; the secrets/QA move is a call to make deliberately when we reach it, not a foregone conclusion.
- Should the Python helpers merely relocate, or get light cleanup while being moved? Default: relocate only, keep this a pure structural refactor; note any Python smells for a later pass rather than fixing them here.
