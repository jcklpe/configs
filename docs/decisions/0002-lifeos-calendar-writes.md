# 0002 LifeOS Calendar Writes And Attendee Resolution
## Context
LifeOS v1 kept Google Calendar strictly read-only. `AGENT.md` said "do not add Google Calendar write commands," and the `lifeos-tools-v2` scratch notes went further: keep any future writes create-only on a dedicated reminders calendar, and "never create guest events or modify attendee lists from this tool."

That conservatism was about blast radius: calendar events can involve guests, shared/imported calendars, recurring series, and notification side effects. But read-only calendar limits how useful the LifeOS agent can be. The user decided the agent should be able to create and edit events and invite people (e.g. inviting Lindsey), accepting the broader blast radius in exchange for utility — provided the dangerous edges are gated by the tool rather than left to agent discretion.

## Decision
Add `lifeos calendar create-event` and `update-event`, plus a `people` command group for attendee resolution. The capability is real (guests and attendee-list edits included), but constrained by tool-enforced safety properties:

- **Dry-run by default; `--execute` to write.** Every write prints the full plan/diff and changes nothing without `--execute`. Mirrors the Open Austin issue-creation pattern, not the immediate-write Trello pattern.
- **Writable-calendar allowlist.** Writes are rejected unless the target calendar is in `LIFEOS_CALENDAR_WRITABLE_IDS` (default `primary`). Reads still span every configured calendar; writes cannot touch shared/work/partner calendars. There is no `delete-event`.
- **No attendee email-out by default.** `sendUpdates=none` unless `--notify` is passed. Adding an attendee with `--notify` sends a live invite — that is the real blast radius, so it is opt-in per write.
- **Recurring edits default to the single occurrence.** `update-event` edits only the passed instance; `--series` retargets the series master. Attendee edits merge into the existing list unless `--replace-attendees`.
- **Attendee resolution is layered and never guesses.** Order: literal email (`@`) → local alias map (`people-aliases.json`, gitignored) → Google People API. Ambiguous or unmatched People API names stop the write and list candidates rather than picking. The agent disambiguates interactively via `people resolve NAME --json`, then proceeds with the chosen email and may persist it with `people add-alias`.

Scopes on the calendar token expand from read-only to `calendar.events` (read+write) plus `contacts.readonly` and `contacts.other.readonly`. This requires re-running `lifeos calendar auth` and enabling the People API for the same Google project.

## Consequences
- The LifeOS agent can schedule and adjust events and invite people, which was the goal.
- The prior "calendar is read-only" and "never touch attendees" rules are explicitly retired. `AGENT.md` and the v2 scratch notes are updated to match; this record is the authority if they drift.
- Blast radius is now real but bounded: the worst unattended action is creating/editing an event on an allowlisted calendar without notifying anyone. Emailing real people requires an explicit `--notify`, and editing a whole recurring series requires an explicit `--series`.
- Contacts access is broader than strictly needed (the People API can read all contacts). The local alias map exists partly to avoid depending on it for frequent invitees, whose common first names are ambiguous or unresolvable in Contacts anyway.
- The dedicated `LifeOS Reminders` calendar idea from the v2 notes is no longer the chosen path; the allowlist generalizes it.
- `people-aliases.json` is local and gitignored, so it does not travel with the repo; a LifeOS agent on another machine starts with an empty alias map.

## Links
- [AGENT.md](../../lifeos-tools/AGENT.md) — operational guidance and the disambiguation flow.
- [lifeos-tools/README.md](../../lifeos-tools/README.md)
- [0001 Secrets And Local Env Hygiene](0001-secrets-and-local-env.md) — the alias-file ignore pattern.
- [lifeos-tools-v2 scratch notes](../lifeos-tools-v2.md) — superseded Calendar V2 ideas.
- Implementation: `lifeos-tools/lifeos.sh`, `google-calendar-write.py`, `google-people.py`, `google-calendar-auth.py`.
