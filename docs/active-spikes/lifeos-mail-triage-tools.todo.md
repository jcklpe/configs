# LifeOS Mail Triage Tools — To Do
Concept: [lifeos-mail-triage-tools.md](lifeos-mail-triage-tools.md).

## Current State
- Implemented 2026-09-30: sync reliability, web links, unsubscribe headers, HTML-to-text, and the query override. Live-verified on one Gmail account and one Microsoft 365 account: every message has a link, 8 of each inbox carried unsubscribe headers, and no stylesheet text leaked into bodies. Full offline suite green.
- Waiting on decisions: Microsoft 365 junk training (`reportMessage`) and Outlook categories.

## To Do
- [x] Gmail sync reliability: `_gmail_get` surfaces Google's error reason and message, backs off (2 s, doubling) and retries on 429 and 403 `rateLimitExceeded`/`userRateLimitExceeded` up to `LIFEOS_GMAIL_MAX_RETRIES` (default 5), and names a remedy. `--all` continues past a failing account, reports every failure, exits non-zero, and leaves failed snapshots unchanged.
- [x] Fixed an ordering bug found along the way: per-message files were named `0.json … 10.json` and globbed in text order, so snapshots interleaved out of order. They are now zero-padded.
- [x] Gmail web link in sync output (`- Link:`).
- [x] `List-Unsubscribe` / `List-Unsubscribe-Post` in sync output for both services (`- Unsubscribe:`, marked "one-click supported"). Microsoft 365 requests `internetMessageHeaders`.
- [x] HTML-to-text: both renderers drop `<style>`, `<script>`, `<head>`, and `<title>` content, and Gmail treats an HTML document inside a `text/plain` part as HTML.
- [x] `--query` and `--max-results` overrides on `gmail sync`, refused unless combined with `--output` or `--qa`, so the vault snapshot keeps its configured query.
- [x] Offline tests: `tests/test-mail-sync-triage.sh`, mutation-checked against style skipping, HTML-in-plain detection, rate-limit retry, and `--all` continuation.
- [x] Microsoft 365 junk: checked. Graph's `markAsNotJunk` was beta-only and was retired on 2025-12-30. The replacement, `reportMessage`, reports to Microsoft (outward-facing). `not-junk` stays a folder move; the limit is documented in the `lifeos-m365` skill.
- [x] Docs: `lifeos-gmail` and `lifeos-m365` skills, README, and `lifeos help`.
- [ ] Decision needed: should `not-junk` also call `reportMessage` (a report to Microsoft), behind an opt-in? It would need its own decision record.
- [ ] Deferred until asked: Outlook categories.

## Ready For Human QA
- Read a synced snapshot for one Gmail account and the Microsoft 365 account: do the `Link` lines open the right thread, and do the `Unsubscribe` lines look right?

## Done
- [x] Spike opened (2026-09-30).
- [x] Scope trimmed (2026-09-30): snooze, unsubscribe automation, and a separate listing or read command dropped.
- [x] Implementation above (2026-09-30).
