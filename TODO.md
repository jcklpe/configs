# TODO
This file is the coordination map for active work in this repo. Keep detailed thinking in spike docs, decisions, or scratch notes; keep this file short enough to scan.

## Active Spikes
- LifeOS Code Cleanup — reorganize `configs/lifeos-tools/` and modularize `lifeos.sh` into a dispatcher + feature libs, on maintainability grounds only. No behavior change. Establishes the `lifeos-tools/skills/` seam. `docs/active-spikes/lifeos-code-cleanup.md`, `docs/active-spikes/lifeos-code-cleanup.todo.md`. First of three sibling LifeOS spikes; prerequisite for Vault Runbook Conversion.
- LifeOS Tools v2 — open spike, parking lot for remaining v2 ideas. `docs/active-spikes/lifeos-tools-v2.md`, `docs/active-spikes/lifeos-tools-v2.todo.md`. (Task Chains / `supersede` theme is shipped — see Recently Shipped. Other v2 ideas stay parked.)

## Later Spikes (this conversation, not yet opened)
- LifeOS Handoff — a user-initiated global `lifeos-handoff` skill for feeding progress/accomplishments to the LifeOS vault, plus a one-line LifeOS pointer in `agents/AGENTS.global.md`. Independent of the others; can run anytime.
- Vault Runbook Conversion — sort the vault's runbooks by tool-vs-vault, convert to skills (tool ones to `lifeos-tools/skills/` symlinked global, vault ones physically in the vault), retire the vault's `how-to-spike.md`, vendor a commit-work-stripped `run-project-spike` into the vault. Straddles configs (git) and the vault (Drive-only); depends on LifeOS Code Cleanup.

## Scratch / Future
- LifeOS Bitwarden cleanup (parked): `docs/scratch/lifeos-bitwarden.md`, `docs/scratch/lifeos-bitwarden.todo.md`
- `run` dispatcher notes: `docs/scratch/run-command.md`, `docs/scratch/run-command.todo.md`

## Recently Shipped
- Skill Authority: global skills are position-independent again — a skill's text is true whichever copy is read, so `setup-local-skills` copies verbatim and gained the update path that step 8 used to make impossible. `docs/how-to-spike.md` retired in favour of `skills/run-project-spike/SKILL.md`; the repo migrated to `docs/active-spikes/`; personal prose rules hoisted to `agents/AGENTS.global.md`, symlinked into `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` so they bind in every repo rather than only this one. History in `docs/archive/skill-authority.md` and `docs/archive/skill-authority.todo.md`.
- Commit Work: agents may now commit in this repo and may never push, the line drawn at reversibility rather than importance. `skills/commit-work/SKILL.md` commits by explicit pathspec and never stages, which is what makes two concurrent agents safe; `run-project-spike` invokes it at each completion boundary and at archival. Every spike commit carries a `Spike: <slug>` trailer, so `git log --grep='Spike: <slug>$' --reverse` reconstructs a spike's history in order. Rule recorded in `docs/decisions/0003-agent-commit-policy.md`; history in `docs/archive/commit-work.md` and `docs/archive/commit-work.todo.md`.
- LifeOS Trello Task Chains: `trello supersede` (`--from`/`--to` and `--create`) writes the bidirectional predecessor↔successor link atomically as `🔗 Continues in:` / `🔗 Continues from:` comments (successor-first, idempotent, loud `PARTIAL:` on second-write failure); `trello chain` walks and prints a chain from any card. Live smoke test via the LifeOS agent on 2026-06-25. Notes in `docs/active-spikes/lifeos-tools-v2.md`.
- LifeOS Google Calendar writes: `calendar create-event` / `update-event` (dry-run by default, writable-calendar allowlist, no delete), attendee invites with layered name resolution (alias map → People API) and a `people` command group, single-occurrence-vs-`--series` edits. Recorded in `docs/decisions/0002-lifeos-calendar-writes.md`. First live `--execute` write was a real vault-agent task (no separate smoke test run).

## Next
- Decide when a `docs/runbooks/` folder is useful enough to create.
- Decide which remaining `docs/active-spikes/lifeos-tools-v2.md` theme (Trello write-safety pass, Drive read expansion, read-only `calendar find`, setup helper, agent wrapper) becomes the next active theme. Calendar writes and Task Chains / `supersede` are both shipped.

## Waiting For Human QA
- None.

## Later
- Confirm GitHub Copilot reads `~/.claude/CLAUDE.md`. From a repo with neither `CLAUDE.md` nor `AGENTS.md`, ask whether its instructions contain the heading `Global Agent Instructions` — that string exists only in `agents/AGENTS.global.md`. Copilot answered yes from inside this repo, where its own `CLAUDE.md -> AGENTS.md` symlink makes the answer ambiguous. If it cannot see the global file, `symlinks.sh` needs a Copilot-specific instruction path.
- New-machine runbooks for macOS, Fedora, NixOS, and WSL.
- Shell recovery runbook for broken startup config.
- Leaked-secret rotation runbook if CLI tools start depending on API credentials.
- Decision record for where personal CLI tools should live in this repo.

## Notes
- Finished LifeOS v1 spike history lives in `docs/archive/lifeos-tools.md`, `docs/archive/lifeos-tools.todo.md`, `docs/archive/lifeos-google-sources.md`, and `docs/archive/lifeos-google-sources.todo.md`. The secrets/env spike is in `docs/archive/secrets-env.md`, folded into decision `0001`.
- Use `skills/run-project-spike/SKILL.md` for spike workflow.
- Use `docs/active-spikes/` for the conceptual + to-do pair of each active spike.
- Use `docs/deferred-decisions.md` for questions we are intentionally not answering yet.
- Use `docs/scratch/` for rough, non-authoritative notes.
- Use `docs/archive/` for finished spike history.
- Use `docs/decisions/` for durable tradeoffs and settled repo direction.
- Secrets/local env hygiene is recorded in `docs/decisions/0001-secrets-and-local-env.md`.
- LifeOS calendar writes and attendee resolution are recorded in `docs/decisions/0002-lifeos-calendar-writes.md`.
