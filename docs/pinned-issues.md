# Pinned Issues
This doc is for unresolved issues we are intentionally preserving for later.

"Put a pin in it" means: do not solve this right now, but do not let it vanish into chat history either. Capture the issue, current context, and the moment when it should be revisited.

This is not a backlog for ordinary tasks. Use it for unresolved concerns, questions, or tradeoffs where the right next step depends on future QA, real use, another spike landing first, or clearer project context.

Keep entries brief and plain. When a pinned issue becomes active work, a future idea, a misc note, or a durable decision, move the useful context into the receiving doc and remove the pin. This doc should stay a short live register, not a history of everything ever pinned.

## Current Pins
### Multi-Agent Coordination On Shared Files
Pinned: 2026-07-09

Issue pinned: whether agents need an interface for coordinating when two of them genuinely must touch the same file, or whether that stays a human scheduling problem.

Current context: the user typically runs two agents at once on deliberately separated spikes, planning them so their file scopes do not overlap. Overlap still happens occasionally. The `commit-work` design makes *commits* concurrency-safe by committing named paths and never touching git's shared index, so two agents can no longer contaminate each other's history. That closes the git-level hazard but not the edit-level one: two agents editing the same file still race in the working tree, and the loser's changes are silently overwritten on save. No mechanism currently detects this.

Revisit when: an agent's edits are actually lost or clobbered by a concurrent agent, or when `commit-work` has been in use long enough to show whether spike-scoped file separation holds up in practice. See `docs/archive/commit-work.md`.
