# LifeOS Loop Headless To Do
## Current State
Opened 2026-10-06. Prototype built and installed, with live authentication and authoring validation pending. A read-only headless check reached Microsoft sign-in and returned `login_required` without opening a window. No live Loop write authorized or performed. A dedicated browser sign-in remains a separate prerequisite; never open a headed window implicitly.

## To Do
- Validate live Canvas discovery after the dedicated profile is authenticated; stop rather than guessing if the current Loop UI differs.

## Ready for Human QA
- Authenticate the dedicated profile through the explicit login command, then verify a live document read and approve one concrete append to a disposable component.

## Done
- Inspect existing Microsoft 365 capability gates and upstream Loop browser automation. Existing Graph scopes do not supply a website session; dedicated profile authentication is required.
- Build isolated headless status/read and plain-text append commands, with explicit login and dry-run-first execution. Implemented in `lib/m365-loop.py` and `lib/m365-loop.sh`, wired into `lifeos m365 loop`; optional Playwright dependency and isolated Chromium engines installed. Browser state and engines are ignored before use.
- Verify browser isolation, clipboard-free insertion, stale-preview refusal, dry-run behavior, and persistence checks against an offline editor fixture. Browser fixtures pass, including preservation of existing inline formatting, profile locking, and possibly-applied errors without replaying the edit. The complete existing shell fixture suite passes; bash/zsh dispatch and shell syntax checks pass. Fixtures do not establish that the current live Loop UI works.
- Run a read-only headless check against Loop and report any authentication boundary. On 2026-10-06 the live document check returned `login_required` (exit 3). No headed window was opened and no content was changed.
