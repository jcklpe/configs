---
name: lifeos-calendar
description: "Use legacy lifeos calendar commands with explicit Google account aliases, bounded exports, and guarded event writes."
---
# Legacy Google Calendar Route
Read [use-google-calendar](../../../agent-hands/skills/use-google-calendar/SKILL.md) for supported operations, calendar allowlists, notification controls, timezone/recurrence handling, and failure semantics. Both routes use [authorize-google](../../../agent-hands/skills/authorize-google/SKILL.md)'s adjacent ignored account configuration. Calendar authorization can remain a distinct profile/token from mail and files; do not merge tokens or add grants merely to migrate paths.

Every command now selects an account: `lifeos calendar list-calendars ALIAS`, `find ALIAS QUERY`, `export-data ALIAS --from INSTANT --to INSTANT --output FILE`, `create-event ALIAS ...`, or `update-event ALIAS ...`. `lifeos calendar auth ALIAS` forwards to Google authorization. A former export source label is now an actual configured account alias; verify its mapping before use. Calendar selections, write allowlists, windows, and description preferences live in that profile.

Writes preview by default, require explicit writable IDs and the write gate, and send attendee updates only with `--notify`. Attendees must be full email addresses. `lifeos people resolve ALIAS NAME` returns Google contact candidates without choosing a recipient. Private nickname lookup/storage belongs to the consuming workspace; `people list-aliases` and `people add-alias` are retired. Preserve any private alias preferences in the workspace before dropping old configuration.

Combined sync is retired. Fetch each selected provider explicitly and use [render-calendar-agenda](../../../agent-hands/skills/render-calendar-agenda/SKILL.md) to combine bundles with expected-source checks. The private workflow owns coverage requirements, availability interpretation, and destinations. A single-provider export does not prove complete availability; no live calendar was refreshed by this migration.
