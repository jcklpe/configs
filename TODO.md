# TODO
This file is the coordination map for active work in this repo. Keep detailed thinking in spike docs, decisions, or scratch notes; keep this file short enough to scan.

## Active Spikes
- **LifeOS Microsoft 365:** add delegated Microsoft Graph access for read-only mail plus read/write calendar and Outlook contacts, with dry-run writes and no deletes. See `docs/active-spikes/lifeos-m365.md` and `docs/active-spikes/lifeos-m365.todo.md`.

## Later Spikes (this conversation, not yet opened)
- None.

## Scratch / Future
- Future ideas: `docs/scratch/future-ideas.md`
- LifeOS Bitwarden cleanup (parked): `docs/scratch/lifeos-bitwarden.md`, `docs/scratch/lifeos-bitwarden.todo.md`
- `run` dispatcher notes: `docs/scratch/run-command.md`, `docs/scratch/run-command.todo.md`

## Recently Shipped
- Skill Taxonomy: aligned the project workflow taxonomy around `docs/pinned-issues.md`, `docs/scratch/future-ideas.md`, `docs/scratch/misc.md`, `docs/decisions/`, and `docs/active-spikes/`; added `pin-issue`, `log-future-idea`, `log-skills-feedback`, `write-skills`, and `update-local-skills`; added `agents/skills-feedback-log.md`; migrated LifeOS and `my-website` local skill/docs shapes. History in `docs/archive/skill-taxonomy.md` and `docs/archive/skill-taxonomy.todo.md`.
- LifeOS CLI Skill: converted the old `lifeos-tools/AGENT.md` surface into co-located tool skills under `lifeos-tools/skills/`: `lifeos-cli`, `lifeos-trello`, `lifeos-calendar`, `lifeos-gmail`, `lifeos-drive`, and `lifeos-open-austin`; symlinked them globally and repointed current references. History in `docs/archive/lifeos-cli-skill.md` and `docs/archive/lifeos-cli-skill.todo.md`.
- LifeOS Tools v2: closed the v2 parking-lot spike after Task Chains / `supersede`, Calendar writes, and `calendar find` shipped. Remaining non-active v2 material now lives in `docs/scratch/future-ideas.md`. History in `docs/archive/lifeos-tools-v2.md` and `docs/archive/lifeos-tools-v2.todo.md`.
- LifeOS Handoff: a user-initiated global `lifeos-handoff` skill that produces, from any repo, a sectioned status report (Progress / Growth / Accomplishment) for the LifeOS vault, treating the vault agent as a project manager. Strict attribution — it credits the user's direction/judgment on AI-executed work rather than claiming they hand-did it — and produce-only, never presupposing the vault's structure. Plus a one-line LifeOS pointer in `agents/AGENTS.global.md`, symlinked global. History in `docs/archive/lifeos-handoff.md` and `docs/archive/lifeos-handoff.todo.md`. Second of three sibling LifeOS spikes.
- LifeOS Code Cleanup: `lifeos-tools/` reorganized from a junk-drawer root into a dispatcher plus `lib/` (feature modules `trello`/`google`/`open-austin-org` over shared `common.sh`, and the `google-*.py` helpers), with secrets in `secrets/` and `--qa` output in `qa/`. `lifeos.sh` went 2,550 → 324 lines with byte-identical behavior throughout (golden `doctor`/`help`/`context` + renderer tests after each step), staying bash-3.2-safe. Human-QA'd: `doctor` passes and `--qa` writes to `qa/`. History in `docs/archive/lifeos-code-cleanup.md` and `docs/archive/lifeos-code-cleanup.todo.md`. First of three sibling LifeOS spikes; unblocks Vault Runbook Conversion (the `lifeos-tools/skills/` seam is settled).
- Skill Authority: global skills are position-independent again — a skill's text is true whichever copy is read, so `setup-local-skills` copies verbatim and gained the update path that step 8 used to make impossible. `docs/how-to-spike.md` retired in favour of `skills/run-project-spike/SKILL.md`; the repo migrated to `docs/active-spikes/`; personal prose rules hoisted to `agents/AGENTS.global.md`, symlinked into `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` so they bind in every repo rather than only this one. History in `docs/archive/skill-authority.md` and `docs/archive/skill-authority.todo.md`.
- Commit Work: agents may now commit in this repo and may never push, the line drawn at reversibility rather than importance. `skills/commit-work/SKILL.md` commits by explicit pathspec and never stages, which is what makes two concurrent agents safe; `run-project-spike` invokes it at each completion boundary and at archival. Every spike commit carries a `Spike: <slug>` trailer, so `git log --grep='Spike: <slug>$' --reverse` reconstructs a spike's history in order. Rule recorded in `docs/decisions/0003-agent-commit-policy.md`; history in `docs/archive/commit-work.md` and `docs/archive/commit-work.todo.md`.
- LifeOS Trello Task Chains: `trello supersede` (`--from`/`--to` and `--create`) writes the bidirectional predecessor↔successor link atomically as `🔗 Continues in:` / `🔗 Continues from:` comments (successor-first, idempotent, loud `PARTIAL:` on second-write failure); `trello chain` walks and prints a chain from any card. Live smoke test via the LifeOS agent on 2026-06-25. History in `docs/archive/lifeos-tools-v2.md`.
- LifeOS Google Calendar writes: `calendar create-event` / `update-event` (dry-run by default, writable-calendar allowlist, no delete), attendee invites with layered name resolution (alias map → People API) and a `people` command group, single-occurrence-vs-`--series` edits. Recorded in `docs/decisions/0002-lifeos-calendar-writes.md`. First live `--execute` write was a real vault-agent task (no separate smoke test run).

## Next
- Decide when a `docs/runbooks/` folder is useful enough to create.
- Promote a LifeOS Tools future idea from `docs/scratch/future-ideas.md` only when one concrete theme becomes active work.

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
- Use `docs/pinned-issues.md` for unresolved issues we are intentionally preserving for later.
- Use `docs/scratch/future-ideas.md` for conceptual someday material that is not ready for active spike work.
- Use `docs/scratch/` for rough, non-authoritative notes.
- Use `docs/archive/` for finished spike history.
- Use `docs/decisions/` for durable tradeoffs and settled repo direction.
- Secrets/local env hygiene is recorded in `docs/decisions/0001-secrets-and-local-env.md`.
- LifeOS calendar writes and attendee resolution are recorded in `docs/decisions/0002-lifeos-calendar-writes.md`.
