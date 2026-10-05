# LifeOS Trello Checklists
Status: active, opened 2026-10-05 at Aslan's request.

## Purpose
Let `lifeos trello` read and write card checklists, so an agent can keep a card's sub-tasks as checklist items while history stays in comments. A consuming vault workflow asked for that split; today the CLI has no checklist commands, so sub-tasks either go unrecorded or get misfiled as comments.

## What Exists (2026-10-05)
- Card writes: `add-card`, `move-card`, `rename-card`, `set-desc`, `comment`, `snooze`, label add/remove/create/delete, `supersede`.
- `sync` renders cards with list, labels, start date, and last activity. It fetches checklists but renders only a per-checklist progress count, not the items.

## Gaps
1. **Read:** render each card's checklists and item states in `sync`, compact enough that a card with no checklist adds nothing.
2. **Create:** add a named checklist to a card, optionally seeded with items.
3. **Add item:** append an item to an existing checklist.
4. **Tick / untick:** set an item complete or incomplete by item ID or exact item name.

Trello's REST API supports all four (`/cards/{id}/checklists`, `/checklists/{id}/checkItems`, `/cards/{id}/checkItem/{idCheckItem}` with `state`).

## Design Notes
- Follow [0006](../decisions/0006-writes-fail-rather-than-guess.md): an ambiguous checklist or item name fails and lists the candidates rather than guessing.
- No item deletion in the first cut. Renaming and reordering wait until someone needs them.

## Decision
- Checklist writes are direct, like the existing Trello writes, not dry-run by default like mail and calendar (2026-10-05). The calling workflow owns approval.

## Out Of Scope
Native due dates on cards or checklist items, item assignment to members, and custom fields. Custom fields may get their own spike if a consuming workflow needs machine-readable card metadata.
