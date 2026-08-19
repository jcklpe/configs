# 0006 Writes Fail Rather Than Guess
## Context
`lifeos calendar create-event` silently planned timed events in `UTC` on a machine whose calendar, OS, and user are all `America/Chicago`. The cause was a resolution chain that degraded quietly: the calendar-metadata read returned 403 under the token's scope, `_calendar_get` is `curl -fsS` so the failure printed nothing, the next fallback (`/etc/timezone`) does not exist on macOS, and the last rung was a hardcoded `printf 'UTC'`. A noon event would have been written at 07:00.

Nothing about the resulting event would have looked wrong. It would have had a real title, a real date, a plausible time, and no error anywhere in the transcript. The only reason the bug was caught at all is that dry-run-by-default (decision 0002) printed `Time zone: UTC` in a plan a human read.

The first fix kept the degrading chain and added `WARN:` lines to it. The user rejected that: a warning on stderr is not a control, because warnings are what gets scrolled past in a long agent transcript, and invisibility of the symptom was the actual defect.

## Decision
**When a write cannot be constructed correctly, fail and surface it. Never complete the write on a guessed value.**

This applies to any `lifeos` write path, not only calendar events. A value that is *load-bearing for correctness* — a time zone, a target calendar, an attendee's address, a record identifier — must be either known or fatal. Defaulting it is only acceptable where being wrong is visible and cheap.

Two obligations come with the stop, and they are what make it acceptable rather than merely obstructive:

- **The error must name the workaround.** The time-zone failure prints the exact flag and a concrete value to use (`--tz America/Chicago`, drawn from the machine's own zone when detectable). Writing is therefore never blocked; it stops being *automatic* in the one case where automatic is unsafe.
- **The error must name the likely cause**, so the underlying breakage can be fixed rather than papered over with the flag forever. The time-zone failure points at `lifeos calendar list-calendars` and the token scope.

Detection helpers may survive as **hint generators** even when they are no longer permitted to supply values. `_system_tz` is retained on exactly this basis: it populates the error message and nothing else.

## Consequences
- A metadata-read outage now stops timed-event writes instead of producing wrong-hour events. This is the intended trade: a visible stop with a one-flag remedy beats an invisible corruption.
- Warnings are not an acceptable substitute for a failure on any correctness-critical value. Where a `WARN:` currently guards one, it should be re-examined.
- Dry-run-by-default (0002) is reinforced rather than replaced. It caught this bug, but it is a *review* gate that depends on a human reading the plan; it is not a correctness guarantee. Both layers are wanted.
- The offline test for a correctness-critical default should assert the **failure** path, not just the happy path — including that nothing is emitted on stdout and that the remedy appears in the error. See `lifeos-tools/tests/test-calendar-tz.sh`.
