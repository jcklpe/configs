---
name: draft-approval-slate
description: "Present a numbered slate of proposed changes for human review before executing external or hard-to-reverse writes — GitHub issues, published docs, shared records, batch edits. Use when a batch of pending create/edit/delete actions should be red-lined first, or when the user asks for an 'approval slate'."
---

# Draft Approval Slate
## Purpose
Before a batch of external or hard-to-reverse changes — creating or editing GitHub issues, posting comments, publishing docs, editing shared records, or any multi-item mutation — gather them into one reviewable slate and present the final copy for the user to red-line. Execute only what the user approves, and only after they have seen what will actually ship.

This is a presentation-and-gating convention, not a heavy process. Keep it light.

## When to use
- A batch of proposed changes touches public or shared state, or is hard to undo.
- The user asks for "an approval slate" or wants to review before you write.
- You are about to run several create/edit calls and the exact wording matters.

Skip it for trivially reversible, local, or clearly pre-authorized single actions.

## The slate
Present every proposed change with:
- **A stable reference label** so the user can approve or reject items individually (see numbering).
- **The final copy that will actually ship** — not a paraphrase. If a body will be posted, show the body.
- **The delta** for edits: current title/state → proposed, so the change is visible.
- **Sequencing** when items depend on each other (e.g. new issues must be created before edits that link them), and a note on any item held for a second review.

## Numbering convention
Number changes by **domain prefix** so a reference is unambiguous and easy to say aloud, rather than bare `1, 2, 3` (which reads as a count — "approve 2" is ambiguous):
- `G#` for GitHub changes (`G1`, `G2`, …)
- `D#` for document / vault / config changes (`D1`, `D2`, …)
- add other prefixes as a slate spans systems (e.g. `C#` calendar, `M#` mail)

The user then approves precisely: "approve G2, hold G5." Avoid decorative glyphs (①/③) — they are hard to read and hard to reference.

## Gating
- Nothing external ships until the user approves it. Respect each repo's or tool's own write-safety rules (dry-run defaults, "plan before bulk", approval-required actions) — this skill sits on top of them, it does not replace them.
- Approval is per-item and per-slate; do not generalize one approval to later items.
- When items change after feedback, re-present the changed items for a final look, keep already-approved items locked, and say which are locked.
- Prefer dry-runs where the tooling supports them, and show the dry-run output as the thing that will ship.

## What not to do
- Do not execute a whole slate off one vague "looks good" when individual items were still in flux — confirm the ones that changed.
- Do not paraphrase copy in the slate and then ship different words.
- Do not crystallize this into a rigid template. A slate is however much structure makes the batch reviewable.
