---
attention: live
---
# LifeOS Calendar Event Settings — Tasks
Opened 2026-10-22. Slug: `lifeos-calendar-event-settings`. [Reasoning](lifeos-calendar-event-settings.md).

## Current State
Free/Busy and one-popup settings are implemented for Google Calendar create/update. Defaults remain unchanged. Sixteen new offline tests, existing timezone tests and shell syntax checks pass. No live event created or updated; no auth or scope changes. Existing unrelated working-tree changes remain outside this spike's checkpoint scope.

## To Do
- Live-verify settings only as part of a separately authorized calendar write; inspect the existing event first after any `PARTIAL` response. Do not create a test event without authorization.
- Review and explicitly authorize closure before archiving the spike.

## Ready for Human QA
- During authorized use, confirm popup delivery in the user's calendar client/device. Stored API settings alone cannot verify client notification permission or delivery.

## Done
- Add explicit availability support to create and update. `--transparency transparent|opaque` serializes the Google field; omitted options preserve defaults/current state and settings-only patches leave other fields out.
- Determine whether explicit personal event reminders are already supported. Existing `--notify` is attendee email only. Added `--popup-minutes 0..40320`, replacing event overrides with one popup and disabling calendar-default reminders only when explicitly supplied.
- Verify explicit settings after an accepted write. Fetches the actual event/master target, checks identity and requested fields, accepts the documented omitted Busy default, and reports `PARTIAL` on failed readback without retrying a write.
- Add synthetic offline tests and maintained usage guidance. Sixteen tests pass, with transport stubbed throughout; existing timezone tests and Bash syntax checks pass. Updated dispatcher help, tool README and Calendar skill. The stable installed wrapper resolves directly to repository files; no rollout step is needed.

## Validation
```sh
PYTHONDONTWRITEBYTECODE=1 python3 agent-hands/compat/lifeos/tests/test-calendar-settings.py
bash agent-hands/compat/lifeos/tests/test-calendar-tz.sh
bash -n agent-hands/compat/lifeos/lib/google.sh
bash -n agent-hands/compat/lifeos/lifeos.sh
git diff --check
```
