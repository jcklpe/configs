# LifeOS Trello Start Dates — To Do
## Background
The Trello snapshot renders `due:` but not `start:`, and `start` is the field the snooze mechanism runs on — so a snoozed card's wake date is invisible in the vault, and a hand-dragged card with no start date (which Butler will never wake) looks identical to a correct one. Conceptual context: `docs/active-spikes/lifeos-trello-start-dates.md`.

## Project Organization
- Fetch: `lifeos-tools/lib/trello.sh`, the card `fields=` list in `_trello_sync` (~line 622).
- Render: `lifeos-tools/lib/trello.sh`, `_trello_render_cards` (~line 492), the card-line expression near the `due:` clause (~line 545).
- Test: `lifeos-tools/tests/test-trello-renderers.sh` (new) + fixtures under `tests/fixtures/`.
- Run the suite: `cd lifeos-tools && for test in tests/test-*.sh; do bash "$test" || exit; done`

## General Principles
- Mirror the existing `due:` rendering — raw ISO, omitted when empty — rather than inventing a new format.
- The one intentional divergence is the `MISSING` marker for `Snoozed` cards, which exists to make a silent breakage loud.
- Offline, fixture-driven tests. No credentials, no network.

## Current State Overview
- `_trello_render_cards "$lists_file" "$cards_file"` is a pure function over two JSON files — directly testable, and currently untested.
- Real-world confirmation the gap matters: card 1991 (`Prep for OSPOSIUM 'Open to Work' career day`) sits in `Snoozed` in the snapshot with no way to tell from the vault when it wakes.

## To Do
- (none)

## Ready for Human QA
- (none)

## Done
- [x] Add `start` to the card `fields=` request in `_trello_sync`. — Done, inserted after `idList` so the request reads in field order.
- [x] Render `| start: <iso>` before the `due:` clause, omitted when empty. — Done. Raw ISO to match `due:`; `// ""` handles Trello returning `start: null` rather than omitting the key.
- [x] Emit `| start: MISSING (snoozed card will never wake)` for a card in the `Snoozed` list with no start date. — Done via the renderer's existing `list_name($id)` helper, so the check costs nothing extra. Scoped to the literal list name `Snoozed`.
- [x] Add `tests/test-trello-renderers.sh` with fixtures covering: start rendered, start omitted, both start and due, and the missing-start-in-Snoozed marker. — Done, plus two assertions the plan did not call for: that the `MISSING` marker does **not** leak into other lists (checked against a `Parked` card with no start), and that a card with a start date is never flagged as missing. **This is the repo's first Trello render test** — `_trello_render_cards` had no coverage at all despite being a pure two-file function, so the fixtures are reusable for any future Trello rendering work.
- [x] Update `lifeos-tools/skills/lifeos-trello/SKILL.md`. — Done. Also corrected the "no separate register needed" sentence, which was the half-true claim that started this: the card was visible, the schedule was not.
- [x] Re-sync the vault snapshot and confirm real snoozed cards show their wake dates. — Done. All **27** snoozed cards render a start date; **zero** `MISSING` markers, so no hand-dragged broken snoozes exist on the board today. Immediately useful: the two cards under audit resolved on sight — OSPOSIUM prep (1991) wakes 2026-09-18 for a Sep 24 event, and the Fall course-load card (1964) wakes 2026-09-04 against a Sep 9 deadline.
- Added, unplanned: observed that snoozes set through the Trello UI land at `13:00Z` rather than the CLI's `12:00Z`. Harmless — Butler compares dates, not times — but it is a reliable tell for whether a snooze was set by hand or by `lifeos trello snooze`, which is useful when auditing.

## Known Edge Cases
- Trello returns `start` as `null` rather than omitting it; the `// ""` guard used for `due` handles that shape.
- A snooze set through `--list` to something other than `Snoozed` will not be flagged when its start date is missing. Accepted: the list name is the only available signal about intent, and guessing is worse.
- Cards may legitimately carry a `start` with no `due` (Trello supports either independently), so neither field may be treated as implying the other.
