---
attention: live
---
# LifeOS Calendar Event Settings
Opened 2026-10-22. Slug: `lifeos-calendar-event-settings`.

## Problem and scope
The Google Calendar writer could create and update events, but it could not explicitly mark an event Free or set a personal popup reminder. A calendar entry used as a reminder therefore could block availability unintentionally or depend on calendar-default notifications. Add these two narrowly bounded settings to the existing create/update path without changing omitted-option behavior.

Scope: `lifeos-tools/lib/google-calendar-write.py`, the Google Calendar writer functions in `lifeos-tools/lib/google.sh`, dispatcher help, tool README, tool-local Calendar skill, synthetic offline tests, this spike pair and its index entry. No changes to shared spike guidance, authentication, credentials, scopes, attendee resolution, Microsoft 365, calendar visibility, or real event records. This public spike contains generic implementation details only; no source calendar data or private workflow context.

## Field model
`--transparency transparent` marks time Free; `--transparency opaque` marks it Busy. Omission preserves Google's default Busy behavior for create and leaves the stored field unchanged on update. Availability and visibility are independent; this option does not make event details private.

The existing `--notify` flag controls attendee email updates through `sendUpdates`, not personal event reminders. No personal reminder override was exposed. `--popup-minutes N` supplies one popup, with `0` meaning event start and an upper bound of `40320`. This intentionally replaces event reminder overrides and sets `useDefault: false`; omission preserves defaults on create and existing settings on update. No email-reminder configuration or reminder-management hierarchy is added.

Both settings use the existing recurring-event targeting: a single occurrence by default, the series master only with `--series`. A settings-only patch does not rewrite title, times, recurrence or attendees.

## Verification model
Dry-runs show the explicit settings and perform no write or post-write fetch. If either new option is supplied with `--execute`, a successful create/update is followed by an event GET at the actual target. Verification checks the event ID, requested transparency and exact single-popup reminder override, including `useDefault: false`. An omitted transparency field in readback means Google's documented default `opaque` and can confirm Busy, but cannot confirm Free.

Failed readback is an accepted-but-unverified write: return nonzero with `PARTIAL`, identify the event where available, and require inspection before another write. Do not automatically retry or recreate. Omitted new options retain the previous write path. This verifies stored settings, not notification delivery by a client or device.

## Evidence and next step
Sixteen new offline tests cover helper serialization, defaults, validation, recurrence, settings-only patches, create/update shell argument propagation, dry-run behavior, attendee notification separation, successful readback, documented Busy defaults, failed/mismatched readback, and series targeting. Existing timezone regression tests and Bash syntax checks pass. All transport in the new integration harness is stubbed; no real calendar writes or credential access were used.

The installed `lifeos` wrapper invokes this repository's files directly, so no reinstall or shell restart is required. Live settings storage and client popup delivery remain unverified until a separately authorized event workflow uses the capability. This spike remains active; implementation is not authorization to close it.

## Maintained guidance
Usage lives in `lifeos-tools/README.md`, dispatcher help and `lifeos-tools/skills/lifeos-calendar/SKILL.md`. API semantics are documented in [Google's Events resource](https://developers.google.com/workspace/calendar/api/v3/reference/events), including transparency, reminder overrides and reminder minutes.
