# LifeOS Bitwarden Cleanup
Status: parked — scratch / future (conceptual doc). Not active work. Promote back to an
active spike only when a concrete cleanup implementation is ready.

Companion to-do: `docs/scratch/lifeos-bitwarden.todo.md`.

## Purpose
Let an agent actually **clean up** the user's Bitwarden vault — real reads and writes
(dedup, fix missing fields, retire stale logins) — not just produce a passive report.
The vault is the user's most sensitive store, so the whole spike is organized around one
hard constraint and a write-safety model that respects it.

This sits alongside the LifeOS tooling in `lifeos-tools/` but is mostly *not* new bash. The
heavy lifting (unlock, read, write) is delegated to the **official Bitwarden MCP server**,
used primarily from the desktop platform apps (Claude/Codex desktop), which is how the user
actually works day to day.

## The One Hard Constraint
The Bitwarden master password lives **only in the user's head**. It is not stored in the
cloud, on paper, in a file, in an env var, or in any agent's context — ever.

Everything else is negotiable. The user is comfortable with session tokens and with *some*
sensitive values passing through an agent. The master password is the single red line.

This constraint is satisfiable because the official Bitwarden MCP server's `unlock` tool
opens a **native OS password dialog**. The password goes head → OS dialog → Bitwarden. It
never crosses the MCP protocol and the LLM never sees it. The server then holds the
resulting session in its own process; the agent operates only *through* session-backed
tools.

## Settled-ish Model
- **Primary surface:** the official Bitwarden MCP server (`@bitwarden/mcp-server`), spawned
  on demand by the desktop app as a stdio subprocess via `npx`. No Docker, no standing
  server, no daemon, no port.
- **Unlock:** agent calls the unlock tool → OS dialog → user types the in-head password →
  session lives in the server process for its lifetime. No master password anywhere on disk
  or in context.
- **No static `BW_SESSION` in config.** The vendor docs show a session token baked into the
  MCP config `env` block. We deliberately omit it. That keeps the config fragment
  **secret-free**, which means it is public-safe and trackable like any other dotfile.
- **Account login is separate from unlock.** A one-time `bw login` per machine establishes
  account auth; it produces locked, encrypted CLI state in the bw CLI's own data dir. That is
  runtime/secret state and stays out of git, consistent with
  `docs/decisions/0001-secrets-and-local-env.md`.
- **Writes are the real risk surface now, not the password.** Cleanup means destructive
  edits and deletes. The safety model is three-layered:
  1. **Backup before cleanup** — export a full vault snapshot so any session is fully
     reversible. (The export is itself plaintext secret material; treat it as ignored,
     short-lived, and deleted after the session.)
  2. **Trash, not permanent** — `bw delete` sends items to trash by default (30-day
     restore). Never use `--permanent` in a cleanup pass.
  3. **Plan before execute** — the agent proposes a concrete change plan ("dedup these 4,
     fix these 6 missing-URL items, trash these 3 stale logins"), the user approves, *then*
     it executes. Preview-before-write, mirroring the Trello write-safety instinct already in
     the v2 notes.
- **Optional thin `lifeos-tools` helper, for analysis only — not plumbing.** The audit
  heuristics (duplicate-by-URL, missing password/URI, stale logins, things Bitwarden's own
  audit misses) can run locally over the exported vault JSON. This is *not* for unlock or
  secret-read plumbing — the MCP server owns that. See the analysis-vs-dump tension below.

## Why A Local Analysis Helper Might Be Worth It
There are two ways to do the audit:

1. **Dump the whole vault into the agent's context** and let the model reason over it. Simple,
   but it pushes *every password in the vault* through the LLM. The user accepts *some*
   sensitive values flowing through an agent; an entire vault of credentials is a different
   order of exposure.
2. **Compute the cleanup plan locally** from the exported vault JSON (a small bash/python
   helper in `lifeos-tools/`), and surface only the *plan* — item names, URLs, reasons — to
   the agent. The agent then drives the approved writes through the MCP server. Far less
   secret material in context for the same outcome.

Option 2 is the stronger fit for this repo's bounded-output, least-exposure house style. The
spike should lean that way unless the MCP server's own audit tooling makes the helper
redundant.

## Goals
- An agent can propose and, after approval, execute vault cleanup writes.
- The master password never touches disk, env, or any agent context.
- The cleanup is reversible (backup + trash-not-permanent).
- The configs footprint stays small and in-character: a package install plus a secret-free
  config fragment, plus an optional analysis helper.

## Non-Goals
- No master password stored anywhere, in any form, ever.
- No static `BW_SESSION` in MCP config; no env-var-password approach.
- **No unattended automation** (cron, headless). Unlock requires a live human at an OS
  dialog. Automation-without-presence is explicitly out of scope.
- Not reimplementing unlock/secret-read plumbing in bash when the MCP server does it more
  safely.
- Not turning LifeOS notes into a secret store. Notes hold *references* (item name/ID); the
  values live in Bitwarden.
- Not a passive report-only feature. Report-only was considered and rejected as too weak for
  the actual goal.
- Headless/no-GUI machines are out of scope for this spike (the unlock dialog needs a
  display; the user's machines have one).

## Vocabulary
- **Unlock dialog** — the native OS password prompt the MCP server raises; the only place the
  master password is ever entered.
- **Session** — the decrypted-vault token the server holds in-process after unlock. Expires /
  dies with the server.
- **Cleanup pass** — a single bounded session of: backup → analyze → propose plan → approve →
  execute writes (to trash, not permanent).
- **Analysis helper** — optional local `lifeos-tools` code that computes the cleanup plan from
  exported vault JSON without sending raw secrets to the model.
- **Reference** — a LifeOS note pointer to a Bitwarden item (name or ID), never a value.

## Relationship To Other Work
- Extends the LifeOS tooling theme; v1 history is in `docs/archive/lifeos-tools.md` and the
  v2 parking lot `docs/active-spikes/lifeos-tools-v2.md` (which already says: CLI is the durable
  boundary, MCP may wrap behavior later, writes need previews and no hard delete — this spike
  honors all three).
- Bound by `docs/decisions/0001-secrets-and-local-env.md` for secret handling.
- The exploration that led here (rejecting env-var passwords, rejecting side-terminal
  handoffs, rejecting report-only, and discovering the MCP unlock dialog) is the reason the
  model looks the way it does. Keep that trail; don't re-litigate it.

## Constraints That Should Shape Implementation
- Cross-machine portability: the install bits belong in the installer; the config fragment
  must stay secret-free to remain trackable.
- Public-repo safety: no vault exports, tokens, or `claude_desktop_config.json` with secrets
  may ever be tracked.
- Least exposure: prefer computing plans locally over dumping the whole vault into context.
- Reversibility: no cleanup pass without a fresh backup and trash-only deletes.
