# Unified Calendar — Todo
See [the conceptual spike](unified-calendar.md).

## Current State
- `_calendar_sync` in `lifeos-tools/lib/google.sh` fetches each configured calendar for the window from `_calendar_window` (`LIFEOS_DAYS_BACK` / `LIFEOS_DAYS_AHEAD`, defaults 14 / 30) and renders one merged agenda through `lib/google-calendar-render.py`.
- `_calendar_sync_combined` in `lifeos.sh` runs the Google sync, then Microsoft 365 calendar sync for enabled aliases, which writes a separate per-alias snapshot. Overlaps between the two are not visible in either file.
- The renderer already merges duplicate events across calendars (`merged_events`) and suppresses descriptions for configured noisy calendars.
- Existing offline coverage: `tests/test-calendar-render.sh` with fixtures under `tests/fixtures/`.

## To Do
### Unified agenda (first)
- [x] Read how `_m365_calendar_sync` fetches and renders (`lib/m365.sh`, `lib/m365-render.py`) and decide the integration point: normalize Graph events into the Google event shape and feed them to `google-calendar-render.py`, or introduce a provider-neutral event shape both renderers consume. Prefer one renderer.
- [x] Normalize Graph events faithfully: start/end with time zone, all-day handling, cancelled status, online-meeting link, location, and calendar label.
- [x] Cross-provider duplicate handling: decide the match key (for example iCalUID when both sides expose it, else title plus start time) and test it. A wrong merge hides a real conflict, so an unmatched pair is safer than a false match.
- [x] Decide what happens to the separate Microsoft 365 calendar snapshot: retire it once unified, or keep it for Graph-specific detail. Avoid rendering the same events at full detail in two files.
- [x] Failure behavior: if the Microsoft 365 fetch fails, the unified file must say so in its header rather than silently rendering a Google-only agenda that looks complete.
- [x] Offline test with invented Google and Graph fixtures covering an overlap across providers and a cross-provider duplicate.

- **Done 2026-09-26 (unified agenda).** New `lib/m365-calendar-normalize.py` converts the Graph fetch into Google-shaped (calendar, events) pairs: fetched in UTC (`_m365_calendar_fetch` gained an optional time-zone override) and converted to the Google primary calendar's IANA zone, so no Windows-to-IANA zone mapping is guessed; all-day events keep their calendar date; `isCancelled` becomes `status: cancelled`; the Teams block after the underscore rule is stripped and the join link kept (from `onlineMeeting.joinUrl`, else the first Teams URL in the body); `iCalUId` carried as `iCalUID`. Graph `$select` gained `iCalUId` and `onlineMeeting`; the Google fetch gained `iCalUID`. `google-calendar-render.py` merges across providers on iCalendar UID plus start instant, in addition to its existing same-ID merge. `_calendar_sync` appends every enabled Microsoft 365 alias through `_calendar_add_m365` and writes a `Microsoft 365 calendars:` block stating each alias as included or `MISSING` with the reason and remedy (fetch failure, unreadable time zone, normalization failure). `lifeos calendar sync` and aggregate `lifeos sync` no longer write the per-alias M365 calendar snapshot (`_m365_calendar_sync_all` removed); `lifeos m365 calendar sync` still does on request. `--google-only` skips M365. Tests: `tests/test-calendar-unified.sh` (conversion, shared-UID merge, look-alike non-merge, Teams stripping, cancelled, all-day, both failure lines); existing render and tz tests still pass. Docs: `lifeos-calendar` and `lifeos-m365` skills, `calendar sync` usage line.
- **Live run 2026-09-26:** one UT calendar included and converted to America/Chicago; UT Teams meetings render with join links and no boilerplate; the unified file was ~12.6k words versus ~14.9k for the two separate files it replaces. No cross-provider duplicates existed in the window, so the merge path is covered by the offline test only.
- [ ] Human QA: Aslan reads the next real `sources/calendar.md` after a sync and confirms the UT events look right.
- [ ] Vault follow-through, in the private vault rather than here: the old per-alias UT calendar snapshot will stop updating and should be removed (with Aslan's approval), and guidance that tells agents to check two calendars separately should point to the one agenda.

### Long horizon
- [ ] Decide the command surface: extend `calendar sync` to write both files (preferred), or add a separate subcommand.
- [ ] Decide whether to fetch once across both windows and split at render time, or fetch the long-horizon window separately. Check `maxResults=2500` and pagination: a six-month window across several calendars may exceed one page, and the current fetch does not follow `nextPageToken`. Silent truncation would be a correctness bug (see decision 0006, writes fail rather than guess, and apply the same spirit to reads: report truncation loudly).
- [ ] Add a compact render mode to `google-calendar-render.py`: one line per event occurrence with date, time or all-day, title, calendar label. Reuse the existing merge and ordering logic rather than a second renderer.
- [ ] Add `LIFEOS_LONG_HORIZON_DAYS` (default ~180). Derive the start as the day after the near-term window's end.
- [ ] Header block for the new file: last refreshed, today, window, and a one-line note that near-term events live in `calendar.md`.
- [ ] Offline test: invented fixtures spanning both windows; assert no event appears in both outputs, that long-horizon lines carry no description, location, or link, and that the boundary day lands in exactly one file.
- [ ] Measure real output size on a live run and record it here (word count for both files).
- [ ] Decide whether recurring weekly events need compacting, based on that real output.
- [ ] Document in the `lifeos-calendar` skill and README: what each file is for and when an agent should read the long-horizon one.

## Ready for Human QA
- [ ] Live run: is the long-horizon file readable and small enough, and does it show the far-off dates that matter?

## Notes / Edge Cases
- Multi-day all-day events that start in the near-term window and continue past its end: decide whether they appear only in the near-term file (where they start) or are clipped into both. No overlap is the rule, so pick one and test it.
- Timed events spanning midnight at the boundary, same question.
