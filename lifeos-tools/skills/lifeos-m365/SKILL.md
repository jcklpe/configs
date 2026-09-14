---
name: lifeos-m365
description: "Use when reading or writing a configured Microsoft 365 account through the lifeos CLI: delegated auth, bounded read-only Inbox snapshots, calendar reads and dry-run-gated event create/update, or Outlook contact reads and dry-run-gated contact create/update."
---

# LifeOS Microsoft 365
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-m365/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

Microsoft 365 uses delegated authentication and account aliases. It is separate from Google Calendar and the Google Gmail/Drive alias layer.

## Setup And Identity
```sh
lifeos setup
lifeos m365 accounts
lifeos m365 auth ALIAS
lifeos m365 profile ALIAS
```

Real account configuration lives in ignored `m365-accounts.json`, copied from `m365-accounts.example.json`. The default `graph-powershell` provider stores its authenticated context in PowerShell's protected CurrentUser cache and never exposes a raw token through the LifeOS CLI. Never print or inspect the real account config or authentication cache. `profile` is the safe way to confirm which mailbox Graph authorized.

Authentication requests the delegated scopes enabled for the alias: `User.Read`, `Mail.Read`, `Calendars.ReadWrite`, and `Contacts.ReadWrite`. Microsoft's shared Graph PowerShell client can have a broader cumulative effective scope set in a managed tenant; this is an accepted transport tradeoff for the configured UT account. Do not expose or add a generic Graph request command. Enforce the narrower LifeOS capability surface below regardless of the authenticated context. There is no client secret and no app-only tenant access.

The optional `msal` provider may be used with a dedicated public-client application ID and its own ignored token cache. It does not change the command safety boundaries.

## Mail
```sh
lifeos m365 mail sync ALIAS --qa
lifeos m365 mail sync ALIAS
```

Mail is strictly read-only. The bounded snapshot covers the configured recent Inbox window and count/body caps. There are no send, reply, forward, move, mark-read, archive, or delete commands.

Production snapshots go to `$LIFEOS_VAULT_PATH/sources/m365/`; `--qa` goes to ignored `lifeos-tools/qa/m365/`.

## Calendar Reads
```sh
lifeos m365 calendar list-calendars ALIAS
lifeos m365 calendar find ALIAS "Orientation"
lifeos m365 calendar sync ALIAS --qa
lifeos m365 calendar sync ALIAS
```

`calendar sync` uses a bounded Graph calendar view so recurring instances and exceptions are expanded across the normal LifeOS date window. `calendar find` returns exact calendar and event IDs for later updates.

## Calendar Writes
```sh
lifeos m365 calendar create-event ALIAS --title "Coffee" --start 2026-08-20T10:00
lifeos m365 calendar update-event ALIAS --event EVENT_ID --location "UTA"
```

Calendar writes are dry-run by default and require `--execute`. They are restricted to `calendar.writable_calendar_ids` in the ignored account config. There is no delete command.

Microsoft may email invitations or meeting updates whenever an attendee-bearing event is created or changed. The CLI therefore rejects attendee-bearing writes unless `--notify` is present. Unlike Google Calendar, `--notify` is an acknowledgement gate, not a Graph switch that can suppress delivery. Confirm every resolved attendee before `--execute`.

Attendees resolve only through literal email addresses or the deterministic local `people-aliases.json` map. The M365 path does not query or guess from the UT directory. Add a stable short name with `lifeos people add-alias NAME EMAIL` if needed.

Updating the description of an online meeting is blocked because replacing its body can remove the Teams meeting data. Recurring-series mutation is not included in the initial M365 surface.

## Outlook Contacts
```sh
lifeos m365 contacts list ALIAS
lifeos m365 contacts find ALIAS "Name"
lifeos m365 contacts sync ALIAS --qa
lifeos m365 contacts create ALIAS --display-name "Name" --email name@example.com
lifeos m365 contacts update ALIAS --contact CONTACT_ID --company "Organization"
```

These commands operate on the signed-in user's default Outlook Contacts folder, not the institutional organization directory. Reads are bounded and do not recurse through additional contact folders. Create/update writes are dry-run by default and require `--execute`; updates require the exact Graph contact ID. Passing `--email` or `--phone` during an update replaces that complete field array, which the dry-run plan displays. There are no contact or folder delete commands.

After any successful calendar or contact write, re-run the corresponding `sync` command to refresh the LifeOS snapshot.

## Files (OneDrive / SharePoint) — implemented but gated
```sh
lifeos m365 files search ALIAS "Work Plan"      # returns drive-item ids
lifeos m365 files meta ALIAS ITEM_ID
lifeos m365 files download ALIAS ITEM_ID --out PATH
```
These require the `Files.ReadWrite` delegated scope, enabled per account with `"files": {"enabled": true}` in `m365-accounts.json`.

**⚠️ Gated on the UT tenant (verified 2026-09-14).** Enabling `files` for the `ut` account and re-consenting hits an **admin-approval wall**: the tenant requires a request-with-justification for the Files scope, so a student account cannot self-grant it. The `files` flag is therefore **disabled by default**; leaving it enabled drags `Files.ReadWrite` into every Graph call and breaks the already-consented mail/calendar/contacts scopes behind the same wall. The commands and scope plumbing are kept in place so this works immediately if UT admin approval is ever obtained. There is no rich Word-editing API (unlike Excel's workbook API), so any future edit path is download → local edit (e.g. python-docx) → `PUT .../content` (OneDrive keeps version history).
