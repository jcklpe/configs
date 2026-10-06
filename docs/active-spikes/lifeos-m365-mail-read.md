# LifeOS Microsoft 365 Mail Read
Status: built and live-checked 2026-10-05; optional sync scope deferred.

## Purpose
Let `lifeos` read the text of any Microsoft 365 message, not only recent Inbox mail. Triage ends by archiving most mail, so the messages a calling workflow later needs (replies to follow up on, assignment emails, sent mail) sit in folders the tools can list but not read. Today the only workaround is moving a message back to the Inbox, which changes its ID and breaks every saved link to it.

## What Exists (2026-10-05)
- `m365 mail sync` reads full bodies, but only for a bounded recent Inbox window.
- `m365 mail list --folder` covers any folder, but returns metadata only: date, sender, subject, ID, categories. No body, no preview, no web link.
- `m365 mail attachments` lists or saves one message's attachments.
- Gmail already has the equivalent: `gmail sync --query … --output FILE` runs any search, archived mail included, into a scratch file.

## Gaps
1. **Read one message by ID** from any folder, including Archive and Sent Items: headers, recipients, text body, attachment names, and the Outlook web link.
2. **Search the mailbox** across folders (Graph `$search`, KQL), so a caller can find "replies from X last week" without knowing the folder.
3. **Optional: folder and search scope on `mail sync`** with `--output` to a scratch file, mirroring `gmail sync --query`.

## Design Notes
- Read-only; uses the existing `Mail.Read` scope. No new permission.
- Same text rendering as `mail sync`: plain-text body via `Prefer: outlook.body-content-type="text"`, the configured body character limit, and HTML-to-text fallback.
- `mail list` should print each message's web link so a found message can be cited without a second call.
- Output goes to stdout or an explicit `--output` file, never the vault's `sources/` snapshot, so the Inbox snapshot keeps its configured scope.
- Junk Email stays excluded from search and read unless explicitly targeted, consistent with the junk-review command.
- Message content is untrusted data; the tool only renders it.

## Decision
- Settled 2026-10-05 as a short inline amendment to 0004 rather than a new record: the change is read-only, uses the same `Mail.Read` scope, and leaves the snapshot's scope alone.

## What Was Built (2026-10-05)
- `m365 mail read ALIAS --message ID [--full] [--json]`: one message from any folder. A single GET with `$expand=attachments($select=…)` returns attachment names without their bytes, and a second small GET names the folder. About 3 seconds over the PowerShell transport.
- `m365 mail list` prints each message's web link, and `--search KQL` runs Graph `$search` across the mailbox or inside one `--folder`. The query is wrapped in double quotes with inner quotes escaped, so `subject:"two words"` works. A mailbox-wide search drops Junk Email hits after the fact and reports the count. About 7 seconds, most of it spent on the folder tree that names each hit's folder.
- Offline tests in `tests/test-m365-mail-read.sh`. Eight deliberate mutations (junk exclusion, attachment expand, list web link, quote escaping, `--full`, folder-lookup failure, attachment lines, body limit) each made the suite fail.

## Out Of Scope
Any mail write beyond what 0007 and 0009 already allow, mark-read, sending, and a generic Graph request command.
