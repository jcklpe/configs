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
- **Do not break the CLI.** It is a live tool the user depends on. There is a `tests/` folder — the refactor must keep it passing, and behavior must be spot-checked against real invocations.
- **Path coupling is where breakage lurks.** Moving secret files (`.env`, `*token*.json`, `*credentials*.json`, `google-accounts.json`, `people-aliases.json`) and QA artifacts requires updating every path that references them in `lifeos.sh` and possibly the Python helpers. Relocating and re-pointing must happen together.
- **Bash portability is an open question.** `lifeos.sh` runs under `#!/usr/bin/env bash`. Whether it targets macOS system bash 3.2 or a newer Homebrew bash affects what is safe — see the open question below.
- **Secrets stay ignored.** After any move, confirm the relocated secret files are still matched by `.gitignore`. A relocation that de-ignores a token would be a leak.

## The Skills Seam
"Establish the seam" means **decide and document** that tool-operation skills live at `lifeos-tools/skills/<name>/SKILL.md`, symlinked into `~/.claude/skills/` and `~/.codex/skills/` for global availability to local agents. It does *not* necessarily mean creating an empty folder now — git does not track empty folders, and the first real tool skill arrives in the conversion spike. The deliverable here is the decision and the documented location, so the conversion spike has a stable target.

## Relationship To Other Spikes
Sibling to `docs/active-spikes/lifeos-handoff.md` (not yet created) and predecessor to `docs/active-spikes/vault-runbook-conversion.md` (not yet created). The conversion depends on this spike having settled where tool skills live. Formal `Continues in:` markers get added when those docs exist.

## Open Questions
- Does `lifeos.sh` rely on bash 4+ features (associative arrays, `${var,,}`, `mapfile`), or is it bash 3.2-safe? This determines whether feature modules can use modern bash and whether the tool assumes Homebrew bash on `PATH`. Answer early — it shapes the refactor.
- How tightly are secret/QA file paths coupled into the code? A grep for the filenames answers it and sizes the relocation risk.
- Should the Python helpers merely relocate, or get light cleanup while they are being moved? Default: relocate only, keep this spike a pure structural refactor; note any Python smells for a later pass rather than fixing them here.
