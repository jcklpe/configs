# 0002 LifeOS Calendar Writes And Attendee Resolution
## Current Approach
The Google Calendar write surface is `bash agent-hands/skills/use-google-calendar/scripts/calendar create-event ALIAS` and `update-event ALIAS`. Use `bash agent-hands/skills/use-google-contacts/scripts/contacts resolve ALIAS NAME` for candidate lookup; the consuming workflow selects exact attendee addresses. Paths in this policy are relative to the configs root. The capability is real (guests and attendee-list edits included), but constrained by tool-enforced safety properties:

- **Dry-run by default; `--execute` to write.** Every write prints the full plan/diff and changes nothing without `--execute`. Execution remains separate from planning.
- **Writable-calendar allowlist.** Writes are rejected unless the target calendar is in the selected account’s `calendar.writable_ids`. Reads still span every configured read calendar; writes cannot touch a target absent from the writable list. There is no `delete-event`.
- **No attendee email-out by default.** `sendUpdates=none` unless `--notify` is passed. Adding an attendee with `--notify` sends a live invite — that is the real blast radius, so it is opt-in per write.
- **Recurring edits default to the single occurrence.** `update-event` edits only the passed instance; `--series` retargets the series master. Attendee edits merge into the existing list unless `--replace-attendees`.
- **Attendee resolution never guesses.** The native Calendar writer accepts explicit addresses. Consumers may resolve private nicknames or use Google Contacts candidate lookup, but must disambiguate before supplying attendee addresses. Nicknames and alias maintenance belong to the private workflow.

Calendar writes request `calendar.events`; separately selected Contacts lookup requests `contacts.readonly` and `contacts.other.readonly`. Use the provider’s `authorize` entrypoint for any separately approved reauthorization and enable the People API only if the Contacts capability is selected. Do not reauthorize merely for migration verification.

## Rationale
Creating and editing events, including invitations, is useful enough to justify a real write surface. Tool-enforced calendar limits, notification acknowledgement, exact attendee resolution, and explicit recurring-series targeting bound its effects. The allowlist supports the permitted calendars without requiring a separate reminders calendar.

## Operating Notes
- The LifeOS agent can schedule and adjust events and invite people, which was the goal.
- Blast radius is now real but bounded: the worst unattended action is creating/editing an event on an allowlisted calendar without notifying anyone. Emailing real people requires an explicit `--notify`, and editing a whole recurring series requires an explicit `--series`.
- Contacts access is broader than strictly needed (the People API can read all contacts). Private workflow nicknames can avoid repeated ambiguous contact lookup, but the tool still receives explicit addresses.
- Private nickname preferences travel only with their consuming workspace; the public tool neither distributes nor edits a personal alias map.

## Links
- [Google Calendar skill](../../agent-hands/skills/use-google-calendar/SKILL.md) — operational guidance and the disambiguation flow.
- [Agent Hands README](../../agent-hands/README.md)
- [0001 Secrets And Local Env Hygiene](0001-secrets-and-local-env.md) — the alias-file ignore pattern.
- [lifeos-tools-v2 archive](../archive/lifeos-tools-v2.md) — superseded Calendar V2 ideas.
- Implementation: `agent-hands/skills/use-google-calendar/scripts/`, `use-google-contacts/scripts/`, and `authorize-google/scripts/`.
