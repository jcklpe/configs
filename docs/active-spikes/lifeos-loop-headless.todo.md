# LifeOS Loop Headless To Do
## Current State
Opened 2026-10-06. Prototype built and installed. Dedicated login completed; two new headless CLI processes subsequently read the same live Canvas and reported editable status without another MFA prompt. Immediate browser-restart session reuse is verified. Longer session retention and live authoring remain unverified. No live Loop write authorized or performed; never open a headed window implicitly.

## To Do
- Measure session reuse after a longer delay if requested; immediate reuse does not establish the tenant's expiry interval.

## Ready for Human QA
- Approve one concrete append to a disposable component, then verify live persistence. The Canvas reports editable status, but no actual live write has been attempted.

## Done
- Inspect existing Microsoft 365 capability gates and upstream Loop browser automation. Existing Graph scopes do not supply a website session; dedicated profile authentication is required.
- Build isolated headless status/read and plain-text append commands, with explicit login and dry-run-first execution. Implemented in `lib/m365-loop.py` and `lib/m365-loop.sh`, wired into `lifeos m365 loop`; optional Playwright dependency and isolated Chromium engines installed. Browser state and engines are ignored before use.
- Verify browser isolation, clipboard-free insertion, stale-preview refusal, dry-run behavior, and persistence checks against an offline editor fixture. Browser fixtures pass, including preservation of existing inline formatting, profile locking, and possibly-applied errors without replaying the edit. The complete existing shell fixture suite passes; bash/zsh dispatch and shell syntax checks pass. Fixtures do not establish that the current live Loop UI works.
- Run a read-only headless check against Loop and report any authentication boundary. The initial 2026-10-06 check returned `login_required` too early during a Microsoft redirect; that result did not establish an expired session. After explicit dedicated login, full Chromium and browser-view URL handling produced successful live read/status checks in two new headless processes. Both found the same text hash, and status reported an editable Canvas. No content changed.
- Correct immediate-reuse failures: share the full Chromium engine between headed/headless launches, request browser view for direct SharePoint `.loop` URLs, wait for silent redirects, and distinguish a stalled blank auth page from a visible sign-in challenge. Offline regression tests cover these URL and redirect cases.
