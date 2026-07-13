---
name: pin-issue
description: "Preserve an unresolved project issue in docs/pinned-issues.md without turning it into a backlog item or durable decision. Use when the user says to put a pin in something, circle back later, defer a thorny question, preserve an unresolved concern, revisit pinned issues, or route a pin into active work, future ideas, misc intake, or a decision record."
---

# Pin Issue
## Local Precedence
If the current repo already has `skills/pin-issue/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Purpose
Use this skill to preserve unresolved issues without interrupting the current work. A pinned issue is something the project is intentionally not resolving yet, but should not lose to chat history, scratch notes, or an overgrown backlog.

The default register is `docs/pinned-issues.md`. Create it only when the user asks to pin, defer, circle back later, revisit, or maintain pinned issues.

## Taxonomy
Use the first matching destination:

- `docs/decisions/` for settled durable rules.
- `docs/pinned-issues.md` for unresolved issues intentionally preserved for later.
- `docs/scratch/future-ideas.md` for conceptual someday material.
- `docs/scratch/misc.md` for raw observed friction, QA nits, bugs, and issue intake.
- `docs/active-spikes/` for active scoped work.

Do not treat `docs/pinned-issues.md` as a pre-decision queue. Some pins become decision records; many become active work, misc notes, future ideas, or nothing.

## What Belongs Here
Pin an issue when the right handling depends on future context, such as:

- visual QA, real usage, user feedback, stakeholder feedback, or production behavior
- another spike, migration, design pass, or implementation phase landing first
- a product, content, design, architecture, process, or project-structure tradeoff that would distract from current work if solved now
- a concern that is real enough to preserve but not ready to classify as a task, idea, or rule

Do not use pinned issues for ordinary tasks, bug lists, wishlist items, implementation details, or conceptual future ideas that already have a better home.

## File Shape
Use this minimal structure:

```md
# Pinned Issues
This doc is for unresolved issues we are intentionally preserving for later.

"Put a pin in it" means: do not solve this right now, but do not let it vanish into chat history either. Capture the issue, current context, and the moment when it should be revisited.

This is not a backlog for ordinary tasks. Use it for unresolved concerns, questions, or tradeoffs where the right next step depends on future QA, real use, another spike landing first, or clearer project context.

## Current Pins
### Short Issue Title
Pinned: YYYY-MM-DD

Issue pinned: ...

Current context: ...

Revisit when: ...
```

## Pinning Workflow
1. Read the current user request, active spike docs, `TODO.md`, and `docs/pinned-issues.md` when they exist.
2. Confirm the item is unresolved and intentionally preserved, not a task, conceptual future idea, raw misc observation, or settled rule.
3. Add a short entry under `## Current Pins`. Preserve the user's framing where it matters, but keep the entry plain and compact.
4. State the pinned issue, the current context that makes pinning reasonable, and the concrete revisit trigger.
5. Prefer a condition-based revisit trigger over a vague date.
6. Link to related active spikes, archived spikes, decision records, issues, or files only when the link will help future review.
7. Avoid duplicating the same work across `docs/pinned-issues.md`, `docs/scratch/`, `TODO.md`, and spike todo docs. One place should own active work.

## Revisiting Workflow
When the user asks to revisit pins, inspect each relevant entry and route it into one outcome:

- **Keep pinned:** update the current context or revisit condition if the issue is still premature.
- **Promote to active work:** move concrete tasks into the relevant spike `.todo.md` or `TODO.md`, then remove the pin.
- **Move to future ideas:** move conceptual someday material to `docs/scratch/future-ideas.md`, then remove the pin.
- **Move to misc:** move raw issue intake or QA observations to `docs/scratch/misc.md`, then remove the pin.
- **Record durable decision:** create or update a decision record under `docs/decisions/`, then remove the pin.
- **Discard:** remove the pin if the issue is no longer relevant.

When promoting a pin, preserve enough origin context in the receiving doc to explain why the issue was pinned. Do not keep a duplicate historical copy in `docs/pinned-issues.md`.

## Hygiene Rules
Keep the register short. It should feel like a clean list of live unresolved calls, not a history log.

Do not add resolved, archived, or completed sections by default. Preserve history in archived spike docs, durable decision records, commit history, or the receiving active work doc.

Do not include private, sensitive, or public-unsafe context in public repositories. Use placeholders or generic phrasing when the pinned issue depends on private information.
