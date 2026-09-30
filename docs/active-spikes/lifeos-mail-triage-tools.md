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
1. **A triage listing with links.** One command per service, or one cross-account command, that lists Inbox messages with a direct web link, read state, current labels or categories, and whether an unsubscribe mechanism is present. It prints to stdout or JSON only, never into snapshot files. Gmail thread links can be built from the thread ID plus the account address (`https://mail.google.com/mail/u/?authuser=ADDRESS#all/THREAD_ID`); Microsoft Graph returns `webLink`.
2. **Read one email in full, on demand**, so a person can review a message beside a drafted reply. Bodies stay out of snapshot files unless the existing sync already includes them.
3. **Outlook categories.** Gmail has labels; the Microsoft 365 side needs `mail categorize` / `uncategorize`: PATCH `categories` on a message, dry-run by default, covered by the existing `Mail.ReadWrite` opt-in, with readback.
4. **Snooze.** Neither Gmail's API nor Microsoft Graph v1.0 exposes native snooze. Options: (a) emulate with a dated label or folder plus a `wake` command the person runs to return due mail to the Inbox (no scheduler); (b) leave snoozing to a task tracker and only archive the mail; (c) both. Needs a decision.
5. **Unsubscribe.** Parse `List-Unsubscribe` and `List-Unsubscribe-Post`. The only candidate for automation is RFC 8058 one-click (an HTTPS POST to the sender's endpoint). `mailto:` unsubscribes would require sending mail, which stays out of scope. One-click unsubscribe is an outward-facing write to a third party, so it needs a decision record amending [0007](../decisions/0007-mail-archive-and-labels.md), dry-run by default, per-message approval, and never following arbitrary links.
6. **Gmail sync reliability.** One configured account's sync has failed since about 2026-09-15 with a bare `curl: (56) ... 403`. The underlying Gmail error is `rateLimitExceeded` on the per-user query-cost quota. The sync fetches every message with `format=full` in quick succession and has no backoff. Wanted: surface Google's error message, back off and retry on rate limits, and fail per account without stopping `--all`. See [0006](../decisions/0006-writes-fail-rather-than-guess.md) for the "name the cause" standard.
7. **Junk training on Microsoft 365.** `not-junk` is a folder move and may not train Outlook's filter. Check whether Graph v1.0 offers a supported not-junk action before relying on the move.

## Out Of Scope
Sending mail, sending replies, creating drafts in the mailbox, deleting or trashing mail, mark-read, filters or rules, and any scheduler. Drafted replies stay in the chat. Whether mailbox drafts are ever wanted is an open question for later.

## Safety
Same model as 0007: exact IDs, dry-run by default, per-call caps, readback, the ignored audit log, and per-account opt-in. Unsubscribe adds third-party network writes, so it gets its own decision and its own opt-in flag. Nothing here writes into the calling vault.

## Related
- [LifeOS Microsoft 365 Mail Archive](lifeos-m365-mail-archive.md), the predecessor.
- [0004](../decisions/0004-lifeos-microsoft-365-access.md), [0006](../decisions/0006-writes-fail-rather-than-guess.md), [0007](../decisions/0007-mail-archive-and-labels.md).
- `lifeos-tools/skills/lifeos-gmail/SKILL.md`, `lifeos-tools/skills/lifeos-m365/SKILL.md`.
