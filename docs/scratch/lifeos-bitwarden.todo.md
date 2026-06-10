# LifeOS Bitwarden Cleanup To-Do

Status: parked — scratch / future (to-do doc). Not active work.

Conceptual doc: `docs/scratch/lifeos-bitwarden.md`.

## Background

Goal: an agent that actually cleans up the Bitwarden vault (real reads + writes), driven from
the desktop platform apps via the official Bitwarden MCP server. One hard constraint: the
master password lives only in the user's head and never touches disk, env, or agent context.
The MCP server's unlock tool (native OS password dialog) satisfies that constraint. Risk has
moved from "the password" to "the writes," so the design centers on a reversible cleanup pass.

## Project Organization

- Conceptual model and settled decisions: `docs/scratch/lifeos-bitwarden.md`.
- This file: concrete work items, current state, QA, edge cases.
- Optional code, if built: `lifeos-tools/` (analysis helper + backup helper only).
- Install bits: `install-script/functions/` (bw CLI).
- MCP config fragment: documented here / optionally symlinked; secret-free.

## General Principles

- Master password: head only, never anywhere else.
- No static `BW_SESSION` in config. Unlock happens live via the OS dialog.
- Every cleanup pass: backup → analyze → propose plan → approve → execute (trash, not
  permanent).
- Prefer local plan computation over dumping the whole vault into agent context.
- Bounded outputs; no token/secret exposure; reversible writes.

## Current State Overview

- Nothing built yet. This is a feasibility spike with a settled-ish model.
- `bw` CLI is NOT installed on this machine (no `bw`, `rbw`, or `op`).
- Confirmed from vendor docs: official `@bitwarden/mcp-server` is a stdio npm package run via
  `npx -y @bitwarden/mcp-server`; prereqs Node 22+ and `@bitwarden/cli`; unlock tool opens a
  native OS password dialog; vault ops need only `BW_SESSION` (which we deliberately do not
  pre-seed). No Docker / no standing server.

## To Do

### Verify before committing
- Confirm the MCP server **holds the session in-process across subsequent tool calls** after a
  dialog unlock (blog lists lock/unlock/sync/status as session tools, strongly implying yes —
  but verify by hand).
- Inventory the MCP server's actual tool surface: which read tools, which write tools (create /
  edit / delete / restore), and whether it exposes its own audit/report tooling that could make
  a local analysis helper redundant.
- Confirm `bw delete` default-to-trash behavior and the restore path/window from both the CLI
  and via the MCP server.
- Confirm the exact `bw export` command(s) for a full reversible snapshot and the format.

### Install / setup
- Add Bitwarden CLI to the installer (brew on mac; check Fedora/Linux availability) in
  `install-script/functions/brew-installs.sh` (and dnf if applicable). Keep idempotent.
- Document the one-time `bw login` step (account auth, separate from unlock). Note where the
  bw CLI stores its locked state and that it stays out of git.
- Write the secret-free MCP config fragment for the desktop app and decide tracking strategy
  (symlink from configs vs. documented runbook one-liner — the app may rewrite the file, so a
  documented snippet may be safer than a symlink).

### Cleanup pass design
- Define the backup step: exact `bw export` command, an ignored short-lived location, and a
  delete-after-session step. Make sure the export location is gitignored before it can exist.
- Define the "propose plan" output shape the agent should produce before any write (item name,
  ID, URL, reason, action). Mirror the Trello dry-run/before-after instinct.
- Define the approval gate (human confirms the plan; no writes before approval).
- Enforce trash-not-permanent: never pass `--permanent` in a cleanup pass.

### Analysis helper (optional — decide after the verify step)
- Decide build vs. skip based on whether the MCP server's own audit tooling is sufficient and
  on the dump-vs-local-plan exposure tradeoff (see conceptual doc).
- If built: small helper in `lifeos-tools/` that reads the exported vault JSON and emits a
  cleanup plan covering duplicate-by-URL, missing password, missing URI, and stale logins —
  surfacing names/URLs/reasons, not raw secrets.
- Add fixtures with fake vault JSON; add a test under `lifeos-tools/tests/`.

### LifeOS vault side
- Define the note-reference convention (e.g. `bw: <item name>` or item ID) so notes point at
  Bitwarden items without storing values. Document that values go into Bitwarden directly, by
  the human, never via an agent.

## Public Safety And Secrets

- Never track: vault exports, `BW_SESSION`, `bw login` state, or any
  `claude_desktop_config.json` containing secrets.
- The MCP config fragment is only trackable *because* it carries no session token. Keep it
  that way.
- Add gitignore rules for any export location before creating it.
- Treat a vault export as compromised if it ever lands in git; rotate accordingly.

## Shell Startup Impact

- None expected. The MCP server is spawned by the desktop app, not from shell startup. Do not
  load any Bitwarden secrets from global shell startup.
- If a `lifeos bw ...` subcommand is added later, it follows the existing lazy `_load_env`
  pattern in `lifeos-tools/lifeos.sh`; no startup cost.

## Install And Symlink Impact

- Adds the `bw` CLI to the install path.
- May add one tracked secret-free config fragment and (optionally) a symlink for it.
- No change to shell load order.

## OS Matrix

- macOS: primary target; desktop apps + GUI for the unlock dialog are present.
- Fedora / generic Linux: bw CLI available; unlock dialog needs a display (fine on a desktop
  session). Verify package source.
- NixOS: defer; note as untested.
- WSL: out of scope for the unlock dialog (no native GUI dialog by default); use the manual
  `bw unlock --raw` fallback only if ever needed. Not a target for this spike.

## Validation Commands

- `command -v bw && bw --version` — CLI present.
- `bw login` then `bw status` — account state without exposing secrets.
- From the desktop app: trigger the MCP unlock tool, confirm the OS dialog appears and the LLM
  never receives the password.
- Dry-run a cleanup plan on a throwaway/test vault item set before touching real items.

## Rollback / Recovery

- Pre-pass `bw export` is the primary rollback.
- Trash-not-permanent means deletes are restorable within Bitwarden's 30-day window.
- If a session misbehaves: `bw lock` / close the desktop app to drop the in-process session.

## Public vs Private

- This spike's docs, the secret-free MCP fragment, the installer change, and any analysis
  helper + fake fixtures are public-safe and belong in this repo.
- Real vault exports, tokens, login state, and the populated desktop-app config are private and
  stay out of git.

## Ready For Human QA

- None yet.

## Done

- Established the model: MCP-server-driven cleanup, OS-dialog unlock keeps the master password
  in-head, writes are the real risk surface, reversible cleanup pass (backup + trash +
  plan-before-execute).
- Rejected, with reasons (keep this trail): env-var master password; static `BW_SESSION` in
  config; side-terminal session handoff for the desktop-app workflow; report-only (too weak for
  the actual cleanup goal).
- Confirmed the MCP server is npx/stdio, not Docker; Node 22+ and bw CLI prereqs.
