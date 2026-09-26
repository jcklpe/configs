# Unified Calendar
**Archived 2026-09-26** after Aslan's review. The live behaviour is documented in the `lifeos-calendar` and `lifeos-m365` skills and the lifeos-tools README; treat this doc as history where they differ.

## Purpose
Two related changes to the calendar snapshots:

1. **One unified agenda across providers.** Microsoft 365 calendars (for example a school or work account) currently sync to their own separate snapshot, so overlaps between them and the Google calendars are invisible unless an agent reads and mentally merges two files. They should render into the same merged agenda as the Google calendars.
2. **A cheap long-horizon view** of commitments further out than the normal snapshot, without making that snapshot larger.

The unified agenda comes first: the long-horizon file inherits whatever the near-term file merges, so it should be built on the unified model rather than on Google alone.

`lifeos calendar sync` renders one merged agenda across every configured Google calendar, from `LIFEOS_DAYS_BACK` (default 14) days back to `LIFEOS_DAYS_AHEAD` (default 30) days ahead, with times, locations, meeting links, and descriptions. Merging calendars into one agenda is deliberate: conflicts and overlaps between calendars are visible in one place. The cost is size. A month of events already renders at roughly 12,000 words, so extending the same format to three or six months would multiply what every agent loads just to see the next few weeks.

Planning, though, regularly needs dates beyond 30 days: term deadlines, project milestones, travel. Today those are invisible to an agent reading the snapshot.

## Settled Model
**Unified, provider-neutral agenda.** Every enabled calendar, Google or Microsoft 365, feeds one merged agenda. Each event line keeps its calendar label so the source stays visible, and cross-provider duplicates (the same meeting invited to both accounts) should merge the way cross-calendar Google duplicates already do, or at least be recognizably the same event.

Then split by **level of detail**, not by calendar:

- **Near term (unchanged):** `calendar.md` keeps its current window and full detail. Conflict-spotting matters here, so descriptions, locations, and links stay.
- **Long horizon (new):** `calendar-long-horizon.md` starts where the near-term window ends and runs to about six months out. It still merges every configured calendar into one agenda, but renders one line per event: date, time or all-day, title, and calendar name. No descriptions, locations, attendees, or meeting links.

**No overlap.** The long-horizon window begins the day after the near-term window ends. Nothing is rendered in both files.

**Loaded on demand.** The long-horizon file is small, but it is still a separate file so agents read it only when they need to look further ahead.

The long-horizon file's name is deliberately explicit, `calendar-long-horizon`, rather than `calendar-horizon`, so its role is clear from a directory listing. The spike was first drafted as "Calendar Long Horizon" and renamed "Unified Calendar" on 2026-09-24 once cross-provider merging joined its scope.

## Decisions (settled 2026-09-26)
- **One event shape, one renderer.** Microsoft 365 events are normalized into the Google event shape and rendered by `google-calendar-render.py`; no second renderer.
- **Duplicates merge only on the shared iCalendar UID** (Google `iCalUID`, Graph `iCalUId`). Unmatched pairs render as two lines, because a false merge hides a real conflict.
- **A failed Microsoft 365 fetch is stated in the file header** ("Microsoft 365 calendar missing — this agenda is Google-only"); it never silently yields a Google-only agenda that looks complete.
- **Teams boilerplate is stripped** from Microsoft 365 descriptions; the join link is kept.
- **The separate per-alias Microsoft 365 calendar snapshot is retired** from the combined sync, so the same events are not rendered twice at full detail. `lifeos m365 calendar sync` remains as an explicit debugging command.
- **Window:** the unified file uses the existing Google window (`LIFEOS_DAYS_BACK` / `LIFEOS_DAYS_AHEAD`, default 14 back / 30 ahead) for both providers.
- **Calendars:** every enabled Microsoft 365 calendar ID feeds the agenda. For the current account only the default calendar is enabled; its built-in holiday and birthday calendars stay off.
- **Order:** unified agenda first, then the long-horizon snapshot.

## Command Surface
Open for the to-do: either `lifeos calendar sync` writes both files in one run (one set of API calls if the fetch can span both windows), or a separate `lifeos calendar sync-long-horizon` exists. Writing both from one sync keeps them consistent with each other and is the current preference.

`LIFEOS_LONG_HORIZON_DAYS` (default about 180) sets the far edge. The near edge is derived from `LIFEOS_DAYS_AHEAD`, never set independently, so the two windows cannot drift into overlapping or leaving a gap.

## Constraints
- Read-only. No calendar writes are involved.
- Same credentials and scopes as the existing syncs. No new OAuth or Graph scope; Microsoft 365 calendar read access already exists.
- Deterministic output ordering, so diffs of the snapshot stay readable.
- Recurring events are expanded like the near-term file (`singleEvents=true`). If weekly recurring events dominate the output, a compact treatment (for example, collapsing an unchanged weekly series into one line) is a candidate refinement, decided from real output rather than up front.
- Cancelled events are excluded, as today.
- No personal calendar names, IDs, or event content in tracked files, fixtures, or docs. Test fixtures use invented data.

## Non-Goals
- No change to the near-term file's window or format.
- No per-calendar split files.
- No descriptions in the long-horizon file, even truncated.
- No calendar writes, and no change to how Microsoft 365 or Google calendar writes work.
