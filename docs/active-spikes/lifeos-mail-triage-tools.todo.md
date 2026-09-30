# LifeOS Mail Triage Tools — To Do
Concept: [lifeos-mail-triage-tools.md](lifeos-mail-triage-tools.md).

## Current State
- Opened 2026-09-30. Nothing implemented. The calling vault's workflow design is happening in parallel; build against its settled needs rather than guessing ahead.

## To Do
### Reliability first
- [ ] Gmail sync: surface Google's error body instead of a bare curl 403, back off and retry on `rateLimitExceeded`, and let `--all` continue past one failing account while reporting it. Add an offline test for the failure path.

### Triage capabilities
- [ ] Triage listing with web links, read state, labels or categories, and unsubscribe presence (JSON and human output).
- [ ] Read one message in full, on demand.
- [ ] Microsoft 365 `mail categorize` / `uncategorize`, with dry-run, readback, and tests.
- [ ] Snooze: decide between a dated label or folder with a `wake` command, task-tracker-only, or both. Then build.

### Unsubscribe (decision first)
- [ ] Decision record amending 0007: RFC 8058 one-click only, per-message approval, opt-in flag, no `mailto:`, no link-following.
- [ ] Implement `unsubscribe` behind that decision, dry-run by default, with the audit log.

### Microsoft 365 junk
- [ ] Check whether Graph v1.0 has a supported not-junk action; update `not-junk` or document the limit.

### Docs
- [ ] Update the `lifeos-gmail` and `lifeos-m365` skills and the README as each capability lands.

## Open Questions
- Should mailbox drafts ever be created, or do replies always stay in chat?
- Is one cross-account `lifeos mail` listing worth adding, or should the per-service commands stay separate?

## Ready For Human QA
- None yet.

## Done
- [x] Spike opened (2026-09-30).
