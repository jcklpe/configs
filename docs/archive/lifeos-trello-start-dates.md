# LifeOS Trello Start Dates
Render each card's `start` date in the Trello snapshot, so a snoozed card's wake date can be audited from the vault instead of only from the Trello UI.

Continues from: docs/active-spikes/lifeos-calendar-timezone.md

## The Gap
`lifeos trello sync` fetches `fields=name,idList,due,url,labels,desc` and renders `due:` on the card line. It never fetches or renders `start`.

The snooze mechanism is built entirely on `start`: `lifeos trello snooze --card X --until YYYY-MM-DD` moves the card to the `Snoozed` list and sets its **start** date to noon UTC on that day, and a Trello Butler rule wakes cards whose start date has arrived. The due date is deliberately left alone, because using `due` for snoozing would create a false deadline.

So the one field that determines when a snoozed card comes back is the one field the snapshot omits. The consequence, found 2026-08-19 while trying to verify a snooze from the vault: **you can see that a card is snoozed but not when it wakes.** The `lifeos-trello` skill's claim that snoozed cards "stay visible in `sources/trello.md` (no separate register needed)" is therefore only half true — the card is visible, the schedule is not.

This also hides the failure mode that actually matters. A card dragged into `Snoozed` by hand in the Trello UI, without a start date, will **never** be woken by Butler. In the snapshot that card is indistinguishable from a correctly snoozed one. A silently-never-waking card is exactly the kind of thing this vault exists to prevent.

## Goals
- Fetch and render `start` on the card line, alongside `due`.
- Make a missing start date on a `Snoozed` card visible as a defect rather than as ordinary absence.
- Add the repo's first Trello render test, since `_trello_render_cards` currently has none.

## Non-Goals
- Do not change how `snooze` writes. The start-date-at-noon-UTC convention is settled and correct; this spike only makes it legible.
- Do not add a `start` write flag to other card commands. Nothing has asked for one.
- Do not reformat or "improve" the existing `due:` rendering. Matching it is the point.
- Do not audit or repair existing snoozed cards as part of the tooling change. Fixing individual cards is vault work, not tool work, and mixing them would make this spike unreviewable.

## Design
Render `start` exactly as `due` is rendered: appended to the card line, raw ISO-8601, `| start: <value>`, omitted when empty.

Raw ISO is deliberate over a prettier `YYYY-MM-DD`. It matches the existing `due:` convention, and the snooze sets noon UTC specifically so the date is stable across US time zones — collapsing it to a bare date would discard the evidence that the convention was followed. A reader loses nothing: the date is the leading component either way.

`start` is placed **before** `due` on the line. For the cards where both appear it reads chronologically, and for the snooze case — by far the common one — the wake date is what the reader came for.

### Surfacing the never-wakes case
A card in a list named `Snoozed` with no start date is a broken snooze. Rendering it as a plain absence would leave the defect as invisible as it is today, so the renderer emits an explicit marker instead:

```
| start: MISSING (snoozed card will never wake)
```

This is a deliberate exception to "just mirror `due`". The list name is the only signal available at render time about whether a start date was *expected*, and a snapshot that can show the bug is worth more than one that is uniformly terse. It follows the same principle settled in `docs/decisions/0006-writes-fail-rather-than-guess.md`: make the broken state loud rather than letting it read as normal.

The check is on the literal list name `Snoozed`, matching what `snooze` defaults to. A custom `--list` target will not be flagged; that is an accepted limitation rather than a reason to guess at intent.

## Constraints
- bash 3.2, and the rendering is `jq` inside a shell heredoc — the existing style.
- Tests are offline and fixture-driven. `_trello_render_cards` takes a lists file and a cards file, so it can be exercised directly with no network and no credentials.
