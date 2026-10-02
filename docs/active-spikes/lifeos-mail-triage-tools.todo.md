# LifeOS Mail Triage Tools — To Do
Concept: [lifeos-mail-triage-tools.md](lifeos-mail-triage-tools.md).

## Current State
- 2026-10-02: scope widened to standing Gmail filters and Microsoft 365 Inbox rules; commands built, tested offline, read-verified live, and all four accounts re-authorized. No filter or rule has been created yet.
- Implemented 2026-09-30: sync reliability, web links, unsubscribe headers, HTML-to-text, and the query override. Live-verified on one Gmail account and one Microsoft 365 account: every message has a link, 8 of each inbox carried unsubscribe headers, and no stylesheet text leaked into bodies. Full offline suite green.
- Decisions settled the same day: no junk report to Microsoft, and Outlook categories added.

## To Do
- [x] Gmail sync reliability: `_gmail_get` surfaces Google's error reason and message, backs off (2 s, doubling) and retries on 429 and 403 `rateLimitExceeded`/`userRateLimitExceeded` up to `LIFEOS_GMAIL_MAX_RETRIES` (default 5), and names a remedy. `--all` continues past a failing account, reports every failure, exits non-zero, and leaves failed snapshots unchanged.
- [x] Fixed an ordering bug found along the way: per-message files were named `0.json … 10.json` and globbed in text order, so snapshots interleaved out of order. They are now zero-padded.
- [x] Gmail web link in sync output (`- Link:`).
- [x] `List-Unsubscribe` / `List-Unsubscribe-Post` in sync output for both services (`- Unsubscribe:`, marked "one-click supported"). Microsoft 365 requests `internetMessageHeaders`.
- [x] HTML-to-text: both renderers drop `<style>`, `<script>`, `<head>`, and `<title>` content, and Gmail treats an HTML document inside a `text/plain` part as HTML.
- [x] `--query` and `--max-results` overrides on `gmail sync`, refused unless combined with `--output` or `--qa`, so the vault snapshot keeps its configured query.
- [x] Offline tests: `tests/test-mail-sync-triage.sh`, mutation-checked against style skipping, HTML-in-plain detection, rate-limit retry, and `--all` continuation.
- [x] Microsoft 365 junk: checked. Graph's `markAsNotJunk` was beta-only and was retired on 2025-12-30. The replacement, `reportMessage`, reports to Microsoft (outward-facing). `not-junk` keeps moving rescued mail into the Inbox; the no-filter-training limit is documented in the `lifeos-m365` skill.
- [x] Docs: `lifeos-gmail` and `lifeos-m365` skills, README, and `lifeos help`.
- [x] `not-junk` decision (Aslan, 2026-09-30): rescued mail goes into the Inbox and is triaged like any other item, which is current behavior. No report to Microsoft.
- [x] Outlook categories (Aslan asked 2026-09-30): `m365 mail categorize` / `uncategorize`, categories shown in `mail list` and the snapshot, offline tests, a live add-then-remove round trip on one UT message, and a 0007 addendum.
- [x] UT full-inbox view: no change (Aslan, 2026-09-30: not broken, don't fix). Older UT mail is listed with `mail list`, metadata only.
- [x] Scope widened to standing filters and rules (Aslan, 2026-10-02), recorded in [0009](../decisions/0009-mail-filters-and-rules.md) with a 0007 amendment.
- [x] Gmail filters: `gmail filters`, `create-filter` (from/to/subject/query; one user label and/or skip Inbox), `delete-filter`; dry run previews recent matches. Needs `gmail.filters_enabled` (adds `gmail.settings.basic`).
- [x] Microsoft 365 Inbox rules: `m365 mail rules`, `create-rule` (from/sender-contains/subject-contains; category, allowed-folder move, stop), `delete-rule`. Needs `mail.rules_enabled` (adds `MailboxSettings.ReadWrite`).
- [x] Offline tests: `tests/test-mail-filters.sh`. Live reads verified on all three Gmail accounts and UT (2026-10-02). All three Gmail accounts and UT re-authorized with the new scopes the same day.
- [ ] First live filter and rule creates, each approved by Aslan. 2026-10-02: one Microsoft 365 Inbox rule that assigns a category to mail from two named senders was created on one configured account and confirmed by readback. Two more category rules are approved, waiting on the category name.

## Found in use (2026-09-30)
- [ ] `gmail list`, `gmail spam`, `gmail labels`, and the label commands still fetch with `_google_get_url` (`curl -f`). On Gmail's per-minute rate limit they print a bare `curl: (56) ... 403` with no retry. Route them through `_gmail_get` like the sync. This hit right after a wide `--query` sync on 2026-09-30.
- [ ] One-click (RFC 8058) unsubscribe URLs from Google and Spotify return a 405 when opened in a browser. Consider marking them in the sync output so the triage workflow links to the email instead.

## Ready For Human QA
- None. Aslan confirmed on 2026-09-30 that the `Link` lines open the right threads.

## Done
- [x] Spike opened (2026-09-30).
- [x] Scope trimmed (2026-09-30): snooze, unsubscribe automation, and a separate listing or read command dropped.
- [x] Implementation above (2026-09-30).
