# TODO
This file is the coordination map for active work in this repo. Keep detailed thinking in spike docs, policies, or scratch notes; keep this file short enough to scan.

Portable service spikes, policies and former LifeOS tooling history are owned by [Agent Hands](agent-hands/TODO.md). The parked [Bitwarden evaluation](agent-hands/docs/scratch/bitwarden-capabilities.md) includes runtime credential delivery and the original cleanup proposal.

## Active Spikes
None.

## Completed policy migration
- Agent policy migration (slug `agent-policy-migration`): D19 adopted all five policies and completed routing and numeric-policy retirement on 2026-11-21. Structural validation and source preservation are verified; archived under D21 on 2026-11-21. [Scope](docs/archive/agent-policy-migration.md); [tasks](docs/archive/agent-policy-migration.todo.md).

## Later Spikes (this conversation, not yet opened)
- None.

## Scratch / Future
- `run` dispatcher notes: `docs/scratch/run-command.md`, `docs/scratch/run-command.todo.md`

## Recently Shipped
- Morris reconciliation (closed 2026-11-23): local checkout migration, tool repairs, installed skill routing and reviewed child-first delivery are complete. Ongoing syncing follows README. [History](docs/archive/morris-reconciliation.md); [verification](docs/archive/morris-reconciliation.todo.md).
- Workflow Reconciliation (closed 2026-11-20): selected shared-source delivery, configs/global installation, Agent Hands pins and ordinary macOS client routing are verified. Other consumer work and deferred client/platform checks retain their owners. [History](docs/archive/workflow-reconciliation.md); [acceptance and retained limits](docs/archive/workflow-reconciliation.todo.md).
- Policies Migration (closed 2026-11-02): completed the decisions-to-policies migration, with current rules maintained by configs and Agent Hands. No implementation or human QA remains in this scope. [Historical reasoning](docs/archive/policies-migration.md); [work and verification](docs/archive/policies-migration.todo.md).
- Modular Skill Distribution (closed 2026-11-02): cross-collection extraction, native cutover and consumer ownership are implemented. Original checklist reconciled; remaining client/platform QA and provisioning have their existing owners. [Historical reasoning](docs/archive/modular-skill-distribution.md); [closure and residuals](docs/archive/modular-skill-distribution.todo.md#closure-reconciliation-2026-11-02).
- Private Kaizen Workflow (slug `private-kaizen-workflow`): closed 2026-10-13. Private global/project records, automatic agent capture and review instructions, and user approval before standing-rule changes are installed. Behavioral follow-up continues through Kaizen. [Reasoning](docs/archive/private-kaizen-workflow.md); [tasks](docs/archive/private-kaizen-workflow.todo.md).
- Project Workflow Refinement (slug `project-workflow-refinement`): closed 2026-10-12 after approved global/local skill changes, archive markers, and bounded maintenance. The prompted read-only exercise supplies little evidence of behavior in real work; future issues will be logged as they occur. [Reasoning](docs/archive/project-workflow-refinement.md); [tasks](docs/archive/project-workflow-refinement.todo.md).
- Draft Approval Slate skill: sketched a light, general `draft-approval-slate` skill (renamed from `approval-slate` on 2026-08-07 to a verb-first imperative) and documented the numbered `D#`/`G#` convention for human review before external writes. The conceptual and to-do docs are archived in `docs/archive/approval-slate-skill.md` and `docs/archive/approval-slate-skill.todo.md`. The skill is also symlinked into the global Codex and Claude skill paths via `install-script/functions/symlinks.sh`.
- Skill Taxonomy: aligned the project workflow taxonomy around `docs/pinned-issues.md`, `docs/scratch/future-ideas.md`, `docs/scratch/misc.md`, `docs/decisions/`, and `docs/active-spikes/`; added `pin-issue`, `log-future-idea`, `log-skills-feedback`, `write-skills`, and `update-local-skills`; migrated LifeOS and `my-website` local skill/docs shapes. History in `docs/archive/skill-taxonomy.md` and `docs/archive/skill-taxonomy.todo.md`.
- LifeOS Handoff: a user-initiated global `lifeos-handoff` skill that produces, from any repo, a sectioned status report (Progress / Growth / Accomplishment) for the LifeOS vault, treating the vault agent as a project manager. Strict attribution — it credits the user's direction/judgment on AI-executed work rather than claiming they hand-did it — and produce-only, never presupposing the vault's structure. Plus a one-line LifeOS pointer in `agents/AGENTS.global.md`, symlinked global. History in `docs/archive/lifeos-handoff.md` and `docs/archive/lifeos-handoff.todo.md`. Second of three sibling LifeOS spikes.
- Skill Authority: global skills are position-independent again — a skill's text is true whichever copy is read, so `setup-local-skills` copies verbatim and gained the update path that step 8 used to make impossible. `docs/how-to-spike.md` retired in favour of `skills/run-project-spike/SKILL.md`; the repo migrated to `docs/active-spikes/`; personal prose rules hoisted to `agents/AGENTS.global.md`, symlinked into `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` so they bind in every repo rather than only this one. History in `docs/archive/skill-authority.md` and `docs/archive/skill-authority.todo.md`.
- Commit Work: agents may now commit in this repo and may never push, the line drawn at reversibility rather than importance. `skills/commit-work/SKILL.md` commits by explicit pathspec and never stages, which is what makes two concurrent agents safe; `run-project-spike` invokes it at each completion boundary and at archival. Every spike commit carries a `Spike: <slug>` trailer, so `git log --grep='Spike: <slug>$' --reverse` reconstructs a spike's history in order. Rule recorded in `docs/policies/0003-agent-commit-policy.md`; history in `docs/archive/commit-work.md` and `docs/archive/commit-work.todo.md`.
- LifeOS Google Calendar writes: `calendar create-event` / `update-event` (dry-run by default, writable-calendar allowlist, no delete), attendee invites with layered name resolution (alias map → People API) and a `people` command group, single-occurrence-vs-`--series` edits. Recorded in `agent-hands/docs/archive/agent-policy-retirements/0002-lifeos-calendar-writes.md`. First live `--execute` write was a real vault-agent task (no separate smoke test run).

## Next
- Decide when a `docs/runbooks/` folder is useful enough to create.

## Waiting For Human QA
- None.

## Later
- Confirm GitHub Copilot reads `~/.claude/CLAUDE.md`. From a repo with neither `CLAUDE.md` nor `AGENTS.md`, ask whether its instructions contain the heading `Global Agent Instructions` — that string exists only in `agents/AGENTS.global.md`. Copilot answered yes from inside this repo, where its own `CLAUDE.md -> AGENTS.md` symlink makes the answer ambiguous. If it cannot see the global file, `symlinks.sh` needs a Copilot-specific instruction path.
- New-machine runbooks for macOS, Fedora, NixOS, and WSL.
- Shell recovery runbook for broken startup config.
- Leaked-secret rotation runbook if CLI tools start depending on API credentials.
- Policy for where personal CLI tools should live in this repo.

## Notes
- Finished LifeOS v1 spike history lives in `agent-hands/docs/archive/lifeos-tools.md`, `agent-hands/docs/archive/lifeos-tools.todo.md`, `agent-hands/docs/archive/lifeos-google-sources.md`, and `agent-hands/docs/archive/lifeos-google-sources.todo.md`. The secrets/env spike is in `docs/archive/secrets-env.md`, folded into decision `0001`.
- Use `project-workflows/run-project-spike/SKILL.md` for active bounded workstreams.
- Use `docs/active-spikes/` for the conceptual + to-do pair of each active spike.
- Use `project-workflows/capture-for-later/SKILL.md` for individual saved or parked scratch notes. A sentence and `status: captured` or `status: parked` suffice; capture adds no automatic tasks or spike.
- Use `docs/scratch/` for rough, non-authoritative notes.
- Use `docs/archive/` for finished spike history.
- Use `docs/policies/` for current durable rules, defaults, procedures, and useful rationale; revise them directly while Git preserves their history.
- Secrets/local env hygiene is recorded in `docs/policies/0001-secrets-and-local-env.md`.
- LifeOS calendar writes and attendee resolution are recorded in `agent-hands/docs/archive/agent-policy-retirements/0002-lifeos-calendar-writes.md`.
