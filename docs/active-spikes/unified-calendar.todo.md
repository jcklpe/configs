# Unified Calendar — Todo
See [the conceptual spike](unified-calendar.md).

## Current State
- `_calendar_sync` in `lifeos-tools/lib/google.sh` fetches each configured calendar for the window from `_calendar_window` (`LIFEOS_DAYS_BACK` / `LIFEOS_DAYS_AHEAD`, defaults 14 / 30) and renders one merged agenda through `lib/google-calendar-render.py`.
- `_calendar_sync_combined` in `lifeos.sh` runs the Google sync, then Microsoft 365 calendar sync for enabled aliases, which writes a separate per-alias snapshot. Overlaps between the two are not visible in either file.
- The renderer already merges duplicate events across calendars (`merged_events`) and suppresses descriptions for configured noisy calendars.
- Existing offline coverage: `tests/test-calendar-render.sh` with fixtures under `tests/fixtures/`.

## To Do
### Unified agenda (first)
- [ ] Read how `_m365_calendar_sync` fetches and renders (`lib/m365.sh`, `lib/m365-render.py`) and decide the integration point: normalize Graph events into the Google event shape and feed them to `google-calendar-render.py`, or introduce a provider-neutral event shape both renderers consume. Prefer one renderer.
- [ ] Normalize Graph events faithfully: start/end with time zone, all-day handling, cancelled status, online-meeting link, location, and calendar label.
- [ ] Cross-provider duplicate handling: decide the match key (for example iCalUID when both sides expose it, else title plus start time) and test it. A wrong merge hides a real conflict, so an unmatched pair is safer than a false match.
- [ ] Decide what happens to the separate Microsoft 365 calendar snapshot: retire it once unified, or keep it for Graph-specific detail. Avoid rendering the same events at full detail in two files.
- [ ] Failure behavior: if the Microsoft 365 fetch fails, the unified file must say so in its header rather than silently rendering a Google-only agenda that looks complete.
- [ ] Offline test with invented Google and Graph fixtures covering an overlap across providers and a cross-provider duplicate.

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
