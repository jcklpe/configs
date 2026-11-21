---
id: BOUND-COMMITS
type: operational
scope: "Agent Git checkpoints, history changes and publication in configs."
status: proposed
authority: ""
revised: "2026-11-21"
depends_on: ["PROTECT-SECRETS"]
related_to: []
---
# Preserve scoped local checkpoints
Agents may make routine in-scope local commits without individual approval. Agents may never push under this standing policy. Explicit pre-commit review holds remain in force until the review ends or the user authorizes the checkpoint. Closing a spike requires closure authorization and review of its complete archival message; wording approval alone does not authorize closure.

Commit coherent changes promptly at useful completion, experiment, correction or recovery boundaries. Include implementation and its directly related documentation and tracking; separate unrelated purposes. Do not commit merely because a conversation ended or wait for an entire spike when a useful checkpoint is ready.

Use explicit pathspec commits. Do not stage tracked changes, make bare commits, use `git commit -a`, force-add ignored files, or bypass verification with `--no-verify`. Check ignores before the procedure's exception for adding new files. Inspect full selected diffs: selecting a path does not isolate overlapping work inside it. Preserve unrelated changes and resolve unknown ownership, incomplete overlapping work or dependencies before committing. Unrelated dirty paths alone are no reason to stop independent authorized work.

Never rewrite history on the agent's own authority. A user-directed rewrite must identify the branch, range and intended result, account for concurrent dependents, and preserve a verified unique recovery reference plus any uncommitted inputs it could disturb. Retain that reference until the user directs otherwise. Verify the intended sequence and messages, identical final contents for a content-preserving rewrite, or exactly the reviewed content differences otherwise. Recovery does not retract distributed copies or authorize a push.

Do not put commit hashes in durable docs; use stable `Spike:` handles. Spike commits carry a bare-slug `Spike:` trailer. Never add a `Co-Authored-By:` trailer. Keep private content and agent proposals distinct from authorized public facts under PROTECT-SECRETS.

Do not run or change the user's `gitall` or `gitcommit` sweep helpers while an agent is working. They can absorb unrelated work through the shared index. The human's `gitpush` helper remains unchanged.

[Commit Work](../../project-workflows/commit-work/SKILL.md) owns command mechanics, guarded new-file handling, recovery checks and message formatting. [Run Project Spike](../../project-workflows/run-project-spike/SKILL.md) owns spike tracking and closure procedure.
