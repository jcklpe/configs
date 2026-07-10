# Deferred Decisions
This doc is for decisions we are intentionally putting a pin in.

"Put a pin in it" means: do not solve this right now, but do not let it vanish into the chat history either. Capture the question, the current context, and the moment when it should be revisited.

This is not a backlog for ordinary tasks. Use it for product, content, design, architecture, or process decisions where the right answer depends on future visual QA, real content, user feedback, or another spike landing first.

Keep entries brief and plain. When a pinned decision becomes active work, move the concrete tasks into the relevant spike todo doc or `TODO.md`, then delete traces of that work from this doc. We want this doc to remain relatively short and clean, not maintain a long history of every single thing that was ever pinned.

## Current Pins
### Multi-Agent Coordination On Shared Files
Pinned: 2026-07-09

Decision deferred: whether agents need an interface for coordinating when two of them genuinely must touch the same file, or whether that stays a human scheduling problem.

Current context: the user typically runs two agents at once on deliberately separated spikes, planning them so their file scopes do not overlap. Overlap still happens occasionally. The `commit-work` design makes *commits* concurrency-safe by committing named paths and never touching git's shared index, so two agents can no longer contaminate each other's history. That closes the git-level hazard but not the edit-level one: two agents editing the same file still race in the working tree, and the loser's changes are silently overwritten on save. No mechanism currently detects this.

Revisit when: an agent's edits are actually lost or clobbered by a concurrent agent, or when `commit-work` has been in use long enough to show whether spike-scoped file separation holds up in practice. See `docs/archive/commit-work.md`.
