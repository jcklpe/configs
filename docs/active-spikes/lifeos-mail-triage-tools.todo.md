# LifeOS Mail Triage Tools — To Do
Concept: [lifeos-mail-triage-tools.md](lifeos-mail-triage-tools.md).

## Current State
- Opened 2026-09-30; scope trimmed the same day to deterministic additions to the existing sync. Nothing implemented.

## To Do
- [ ] Gmail sync reliability: surface Google's error body, back off and retry on `rateLimitExceeded`, and let `--all` continue past a failing account while reporting it. Offline test for the failure path.
- [ ] Gmail web link in sync output (renderer change and test).
- [ ] `List-Unsubscribe` / `List-Unsubscribe-Post` in sync output for both services (fetch the header; renderer; tests).
- [ ] HTML-to-text for HTML-only bodies in both renderers (tests with a synthetic HTML-only fixture).
- [ ] `--query` override on `gmail sync` (test that the account config stays unchanged).
- [ ] Microsoft 365 junk: check for a supported Graph v1.0 not-junk action; update `not-junk` or document the limit.
- [ ] Deferred until asked: Outlook categories.
- [ ] Docs: `lifeos-gmail` and `lifeos-m365` skills and the README as each item lands.

## Ready For Human QA
- None yet.

## Done
- [x] Spike opened (2026-09-30).
- [x] Scope trimmed (2026-09-30): snooze, unsubscribe automation, and a separate listing or read command dropped.
