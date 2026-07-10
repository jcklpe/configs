---
name: track-deferred-decisions
description: "Track intentionally deferred project decisions in a short docs/deferred-decisions.md register. Use when the user says to put a pin in a decision, defer a product/content/design/architecture/process call, revisit a pinned decision, or move a deferred decision into active spike work without turning it into an ordinary backlog."
---

# Track Deferred Decisions
## Local Precedence
If the current repo already has `skills/track-deferred-decisions/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Use this skill to keep postponed decisions visible without interrupting the current work. A deferred decision is a question the project is intentionally not answering yet, but should not lose to chat history, scratch notes, or an overgrown backlog.

The default register is `docs/deferred-decisions.md`. Create it only when the user asks to pin, defer, revisit, or maintain deferred decisions.

## What Belongs Here
Pin a decision when the right answer depends on future context, such as:

- Visual QA that has not happened yet.
- Real content, usage, user feedback, stakeholder feedback, or production behavior.
- Another spike, migration, design pass, or implementation phase landing first.
- A product, content, design, architecture, or process tradeoff that would distract from the current work if solved now.

Do not use deferred decisions for ordinary tasks, bug lists, wishlist items, or implementation details that already belong in a spike `.todo.md` or `TODO.md`.

If the answer is already decided and should guide future work, write or update a durable decision record under `docs/decisions/` instead of pinning it.

## File Shape
Use this minimal structure:

```md
# Deferred Decisions
This doc is for decisions we are intentionally putting a pin in.

"Put a pin in it" means: do not solve this right now, but do not let it vanish into the chat history either. Capture the question, the current context, and the moment when it should be revisited.

This is not a backlog for ordinary tasks. Use it for product, content, design, architecture, or process decisions where the right answer depends on future visual QA, real content, user feedback, or another spike landing first.

Keep entries brief and plain. When a pinned decision becomes active work, move the concrete tasks into the relevant spike todo doc or `TODO.md`, then delete traces of that work from this doc. We want this doc to remain relatively short and clean, not maintain a long history of every single thing that was ever pinned.

## Current Pins
### Short Decision Title
Pinned: YYYY-MM-DD

Decision deferred: ...

Current context: ...

Revisit when: ...
```

Use `to-do.md` only if that is the existing project convention. Prefer `TODO.md` in repos that use the setup-project-docs convention.

## Pinning Workflow
1. Read the current user request, the active spike docs, `TODO.md`, and `docs/deferred-decisions.md` when they exist.
2. Confirm the item is a decision being intentionally deferred, not a task that should be tracked elsewhere.
3. Add a short entry under `## Current Pins`. Preserve the user's framing where it matters, but keep the entry plain and compact.
4. State what decision is deferred, the current context that makes deferral reasonable, and the concrete revisit trigger.
5. Prefer a condition-based revisit trigger over a vague date: "when a specific title pair visibly shivers after typography has been aligned" is better than "later."
6. Link to related active spikes, archived spikes, decision records, issues, or files only when the link will help future review.
7. Avoid duplicating the same work across `docs/deferred-decisions.md`, `TODO.md`, and spike todo docs. One place should own active tasks.

## Revisiting Workflow
When the user asks to revisit pins, inspect each relevant entry and route it into one of these outcomes:

- **Keep pinned:** update the current context or revisit condition if the decision is still premature.
- **Promote to active work:** move concrete tasks into the relevant spike `.todo.md` or `TODO.md`, then remove the pin from `docs/deferred-decisions.md`.
- **Record durable decision:** create or update a decision record under `docs/decisions/`, then remove the pin.
- **Discard:** remove the pin if the question is no longer relevant.

When promoting a pin, preserve enough origin context in the receiving spike or decision record to explain why the question was deferred. Do not keep a duplicate historical copy in `docs/deferred-decisions.md`.

## Hygiene Rules
Keep the register short. It should feel like a clean list of live unresolved calls, not a history log.

Do not add resolved, archived, or completed sections by default. If the project needs history, preserve it in archived spike docs, durable decision records, commit history, or the receiving active work doc.

Do not include private, sensitive, or public-unsafe context in public repositories. Use placeholders or generic phrasing when the deferred decision depends on private information.

## Example Entry
```md
### Animated Title Wrap Hardening
Pinned: 2026-06-23

Decision deferred: whether to add dedicated line/word measurement for titles that participate in featured-media transitions.

Current context: final transition QA is passing, and the current composition removed the last observed title-wrap shiver from the active transition spike. The remaining guidance is to align source/target typography and width first.

Revisit when: a specific future card/list/nav-to-detail title pair visibly shivers after its source and target typography have already been aligned.
```
