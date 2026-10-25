# 0002 LifeOS Calendar Writes And Attendee Resolution
## Current Approach
The Google Calendar write surface is `lifeos calendar create-event` and `update-event`, with the `people` command group for attendee resolution. The capability is real (guests and attendee-list edits included), but constrained by tool-enforced safety properties:

- **Dry-run by default; `--execute` to write.** Every write prints the full plan/diff and changes nothing without `--execute`. Execution remains separate from planning.
- **Writable-calendar allowlist.** Writes are rejected unless the target calendar is in `LIFEOS_CALENDAR_WRITABLE_IDS` (default `primary`). Reads still span every configured calendar; writes cannot touch shared/work/partner calendars. There is no `delete-event`.
- **No attendee email-out by default.** `sendUpdates=none` unless `--notify` is passed. Adding an attendee with `--notify` sends a live invite — that is the real blast radius, so it is opt-in per write.
- **Recurring edits default to the single occurrence.** `update-event` edits only the passed instance; `--series` retargets the series master. Attendee edits merge into the existing list unless `--replace-attendees`.
- **Attendee resolution is layered and never guesses.** Order: literal email (`@`) → local alias map (`people-aliases.json`, gitignored) → Google People API. Ambiguous or unmatched People API names stop the write and list candidates rather than picking. The agent disambiguates interactively via `people resolve NAME --json`, then proceeds with the chosen email and may persist it with `people add-alias`.

The calendar write token needs `calendar.events` (read+write) plus `contacts.readonly` and `contacts.other.readonly`. This requires re-running `lifeos calendar auth` and enabling the People API for the same Google project.

## Rationale
Creating and editing events, including invitations, is useful enough to justify a real write surface. Tool-enforced calendar limits, notification acknowledgement, exact attendee resolution, and explicit recurring-series targeting bound its effects. The allowlist supports the permitted calendars without requiring a separate reminders calendar.

## Operating Notes
- The LifeOS agent can schedule and adjust events and invite people, which was the goal.
- Blast radius is now real but bounded: the worst unattended action is creating/editing an event on an allowlisted calendar without notifying anyone. Emailing real people requires an explicit `--notify`, and editing a whole recurring series requires an explicit `--series`.
- Contacts access is broader than strictly needed (the People API can read all contacts). The local alias map exists partly to avoid depending on it for frequent invitees, whose common first names are ambiguous or unresolvable in Contacts anyway.
- `people-aliases.json` is local and gitignored, so it does not travel with the repo; a LifeOS agent on another machine starts with an empty alias map.

## Links
- [lifeos-cli skill](../../agent-hands/compat/lifeos/skills/lifeos-cli/SKILL.md) — operational guidance and the disambiguation flow.
- [Compatibility CLI README](../../agent-hands/compat/lifeos/README.md)
- [0001 Secrets And Local Env Hygiene](0001-secrets-and-local-env.md) — the alias-file ignore pattern.
- [lifeos-tools-v2 archive](../archive/lifeos-tools-v2.md) — superseded Calendar V2 ideas.
- Implementation: `agent-hands/bin/lifeos`, `google-calendar-write.py`, `google-people.py`, `google-calendar-auth.py`.
