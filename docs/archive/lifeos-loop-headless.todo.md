---
attention: historical
---
# LifeOS Loop Headless To Do
Retired 2026-10-22 at the user’s request: Loop will not be used. Slug: `lifeos-loop-headless`. The adapter, commands, optional dependency, and feature-specific tests were removed. The original implementation record below is historical; its remaining work and live QA are cancelled. No successor spike.

## State Before Retirement
Opened 2026-10-06. Prototype built and installed. Dedicated login completed; two new headless CLI processes subsequently read the same live Canvas and reported editable status without another MFA prompt. Immediate browser-restart session reuse is verified; longer retention remains unknown. A subsequently authorized live document transfer exposed unreliable multiline keyboard insertion and incomplete reads of virtualized pages. The transfer was corrected with one browser-local rich paste, and its entire text order and hyperlink targets were verified in a fresh browser with a sufficiently tall viewport. This task-specific repair is not implemented in the CLI. Do not use the current CLI append for live documents; never open a headed window implicitly.

## To Do
None; retired.

## Ready for Human QA
None; cancelled with retirement.

## Done
- Retire the unused integration (2026-10-22). Removed commands, adapter, optional Playwright dependencies, and feature-specific tests; archived this spike and retired dependent workflow routes. Remaining Microsoft shell fixtures, bash/zsh CLI-help checks, removed-command rejection, shell syntax, and offline lockfile validation pass. Later checkpoint note, 2026-10-24: the repository privacy review is complete and local checkpointing is authorized; historical findings are recorded in the modular skill distribution spike.
- Dropped on retirement (2026-10-22): Replace rapid line-by-line keyboard appends with a verified browser-local paste path; do not replay the failed mutation. Preserve rich content when transferring a source document, and verify persistence before reporting success.
- Dropped on retirement (2026-10-22): Read complete virtualized documents rather than the initially mounted viewport. Exclude collaboration decorations from text hashes and account for native Loop hyperlink spans during verification.
- Dropped on retirement (2026-10-22): Measure session reuse after a longer delay if requested; immediate reuse does not establish the tenant's expiry interval.
- Dropped on retirement (2026-10-22): After the insertion and complete-read fixes, validate the CLI against a disposable live component with an explicitly approved payload. Offline fixtures missed the live virtualization and insertion-order problems.
- Validate an explicitly authorized live source-document transfer. The first approximately 6 KB keyboard append reordered a section; page virtualization also made initial readbacks look truncated. A browser-local HTML/text paste repaired the content, preserved headings and hyperlink targets, and saved successfully. Fresh full-viewport verification matched every source paragraph in order and every linked reference. No task content, account identity, or source URLs belong in this public repository.
- Inspect existing Microsoft 365 capability gates and upstream Loop browser automation. Existing Graph scopes do not supply a website session; dedicated profile authentication is required.
- Build isolated headless status/read and plain-text append commands, with explicit login and dry-run-first execution. Implemented in `lib/m365-loop.py` and `lib/m365-loop.sh`, wired into `lifeos m365 loop`; optional Playwright dependency and isolated Chromium engines installed. Browser state and engines are ignored before use.
- Verify browser isolation, clipboard-free insertion, stale-preview refusal, dry-run behavior, and persistence checks against an offline editor fixture. Browser fixtures pass, including preservation of existing inline formatting, profile locking, and possibly-applied errors without replaying the edit. The complete existing shell fixture suite passes; bash/zsh dispatch and shell syntax checks pass. Fixtures do not establish that the current live Loop UI works.
- Run a read-only headless check against Loop and report any authentication boundary. The initial 2026-10-06 check returned `login_required` too early during a Microsoft redirect; that result did not establish an expired session. After explicit dedicated login, full Chromium and browser-view URL handling produced successful live read/status checks in two new headless processes. Both found the same text hash, and status reported an editable Canvas. No content changed.
- Correct immediate-reuse failures: share the full Chromium engine between headed/headless launches, request browser view for direct SharePoint `.loop` URLs, wait for silent redirects, and distinguish a stalled blank auth page from a visible sign-in challenge. Offline regression tests cover these URL and redirect cases.
