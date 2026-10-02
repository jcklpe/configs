# LifeOS Mail Triage Tools
Status: active, opened 2026-09-30 at Aslan's request. Continues from [LifeOS Microsoft 365 Mail Archive](lifeos-m365-mail-archive.md), which added archive, folder moves, labels, and spam rescue.

## Purpose
Give the `lifeos` mail commands what an agent needs to walk a person through **per-email triage toward inbox zero**: each message gets a recommended outcome, and the person approves outcomes one message at a time. The calling vault owns the workflow and its judgment (what counts as noise, how tasks are framed, where information is filed). This repo supplies the capabilities.

A triage outcome may combine archiving, tagging, turning the email into a follow-up task, snoozing, or filing the information elsewhere. Alternatively it may leave the email for the person, or mark it for later deletion and archive it, optionally unsubscribing. A spam and junk check sits alongside: real mail in Spam is rescued, and spam means scams or unsolicited advertising, not merely unwanted mail.

## What Exists (2026-09-30)
- Gmail: `labels`, `list`, `archive`/`unarchive`, `label [--skip-inbox]`/`unlabel`, `create-label`, `spam`, `not-spam`.
- Microsoft 365: `mail folders`, `mail list`, `mail archive`/`unarchive`, `mail move`, `mail create-folder`, `mail junk`, `mail not-junk`, `mail attachments`.
- Trello `add-card`, `comment`, and `snooze`, for follow-up tasks.
- Bounded Inbox snapshots via `gmail sync` and `m365 mail sync`.

## Gaps
Revised 2026-09-30. The `lifeos` tools stay procedural and deterministic; the triage judgment and the approval slate live in the calling vault's skill, not here. Most of what triage needs already exists in `gmail sync` / `m365 mail sync`, which write IDs, sender, subject, date, labels, read state, and body text (to the vault, or to any `--output` file). The remaining gaps are additions to that sync, not new commands:

1. **Gmail web link** in the sync output: `https://mail.google.com/mail/u/?authuser=ADDRESS#all/THREAD_ID`. Microsoft 365 output already carries Graph's `webLink`.
2. **Unsubscribe header** in the sync output: the `List-Unsubscribe` value (and whether `List-Unsubscribe-Post` one-click is offered), so a person can click it. Unsubscribing itself stays manual.
3. **HTML-to-text** for HTML-only messages. These currently render as raw markup and CSS, so their bodies are unreadable in the snapshot.
4. **A query override** (for example `--query`) on `gmail sync`, so a one-off run into a scratch `--output` file can see beyond the configured window without changing the account config.
5. **Rate-limit reliability.** One configured account's sync failed from about 2026-09-15 with a bare `curl: (56) ... 403`. The underlying Gmail error was `rateLimitExceeded` on the per-user query-cost quota. It recovered on 2026-09-30 after the inbox shrank. Surface Google's error message, back off and retry, and let `--all` continue past one failing account ([0006](../decisions/0006-writes-fail-rather-than-guess.md): name the cause).
6. **Outlook categories** (`m365 mail categorize` / `uncategorize`), only if the calling workflow tags Microsoft 365 mail. Deferred until asked.
7. **Junk training on Microsoft 365.** `not-junk` is a folder move and may not train Outlook's filter. Check whether Graph v1.0 has a supported action.
8. **Standing filters and rules** (scope widened 2026-10-02 at Aslan's request). Triage kept re-tagging the same senders by hand, so recurring patterns become Gmail filters and Microsoft 365 Inbox rules, limited to labeling or categorizing, skipping the Inbox, and moving to an allowed folder. See [0009](../decisions/0009-mail-filters-and-rules.md).

Dropped 2026-09-30: **snooze**, which neither Gmail's API nor Graph exposes (people snooze in the mail client); **one-click unsubscribe automation**, since people click the link themselves for now; and **a separate triage listing or full-message read command**, which the sync with `--output` covers.

## Out Of Scope
Sending mail, sending replies, creating drafts in the mailbox, deleting or trashing mail, mark-read, filters or rules that forward, redirect, delete, or mark read, snooze, automated unsubscribing, and any scheduler. Drafted replies stay in the chat. Whether mailbox drafts are ever wanted is an open question for later.

## Safety
Same model as 0007: exact IDs, dry-run by default, per-call caps, readback, the ignored audit log, and per-account opt-in. Items 1–7 are reads or output-format changes; item 8 writes standing rules, under its own opt-in flags (`gmail.filters_enabled`, `mail.rules_enabled`) and [0009](../decisions/0009-mail-filters-and-rules.md).

## Related
- [LifeOS Microsoft 365 Mail Archive](lifeos-m365-mail-archive.md), the predecessor.
- [0004](../decisions/0004-lifeos-microsoft-365-access.md), [0006](../decisions/0006-writes-fail-rather-than-guess.md), [0007](../decisions/0007-mail-archive-and-labels.md), [0009](../decisions/0009-mail-filters-and-rules.md).
- `lifeos-tools/skills/lifeos-gmail/SKILL.md`, `lifeos-tools/skills/lifeos-m365/SKILL.md`.
