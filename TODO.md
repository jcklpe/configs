# TODO
This file is the coordination map for active work in this repo. Keep detailed thinking in spike docs, decisions, or scratch notes; keep this file short enough to scan.

## Active Spikes
- Skill Authority — restore position-independence to the global skills, give `setup-local-skills` an update path, retire `docs/how-to-spike.md`, migrate `docs/` to `docs/active-spikes/`. `docs/active-spikes/skill-authority.md`, `docs/active-spikes/skill-authority.todo.md`.
- LifeOS Tools v2 — open spike, parking lot for remaining v2 ideas. `docs/active-spikes/lifeos-tools-v2.md`, `docs/active-spikes/lifeos-tools-v2.todo.md`. (Task Chains / `supersede` theme is shipped — see Recently Shipped. Other v2 ideas stay parked.)

## Scratch / Future
- LifeOS Bitwarden cleanup (parked): `docs/scratch/lifeos-bitwarden.md`, `docs/scratch/lifeos-bitwarden.todo.md`
- `run` dispatcher notes: `docs/scratch/run-command.md`, `docs/scratch/run-command.todo.md`

## Recently Shipped
- Commit Work: agents may now commit in this repo and may never push, the line drawn at reversibility rather than importance. `skills/commit-work/SKILL.md` commits by explicit pathspec and never stages, which is what makes two concurrent agents safe; `run-project-spike` invokes it at each completion boundary and at archival. Every spike commit carries a `Spike: <slug>` trailer, so `git log --grep='Spike: <slug>$' --reverse` reconstructs a spike's history in order. Rule recorded in `docs/decisions/0003-agent-commit-policy.md`; history in `docs/archive/commit-work.md` and `docs/archive/commit-work.todo.md`.
- LifeOS Trello Task Chains: `trello supersede` (`--from`/`--to` and `--create`) writes the bidirectional predecessor↔successor link atomically as `🔗 Continues in:` / `🔗 Continues from:` comments (successor-first, idempotent, loud `PARTIAL:` on second-write failure); `trello chain` walks and prints a chain from any card. Live smoke test via the LifeOS agent on 2026-06-25. Notes in `docs/active-spikes/lifeos-tools-v2.md`.
- LifeOS Google Calendar writes: `calendar create-event` / `update-event` (dry-run by default, writable-calendar allowlist, no delete), attendee invites with layered name resolution (alias map → People API) and a `people` command group, single-occurrence-vs-`--series` edits. Recorded in `docs/decisions/0002-lifeos-calendar-writes.md`. First live `--execute` write was a real vault-agent task (no separate smoke test run).

## Next
- Decide when a `docs/runbooks/` folder is useful enough to create.
- Decide which remaining `docs/active-spikes/lifeos-tools-v2.md` theme (Trello write-safety pass, Drive read expansion, read-only `calendar find`, setup helper, agent wrapper) becomes the next active theme. Calendar writes and Task Chains / `supersede` are both shipped.

## Waiting For Human QA
- Skill Authority: does GitHub Copilot read `~/.claude/CLAUDE.md`? From a repo with neither `CLAUDE.md` nor `AGENTS.md`, ask Copilot whether its instructions contain the heading `Global Agent Instructions` — that string exists only in `agents/AGENTS.global.md`. Its earlier "yes" was given from inside this repo, where the answer is ambiguous. This is the only thing keeping that spike open.

## Later
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
