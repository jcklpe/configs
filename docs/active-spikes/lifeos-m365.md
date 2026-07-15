# LifeOS Microsoft 365
Status: active.

Durable access and write-safety decision: `docs/decisions/0004-lifeos-microsoft-365-access.md`.

## Purpose
Add Microsoft 365 as a first-class LifeOS source so the UT mailbox can be the canonical institutional inbox while LifeOS can also read and deliberately write the associated calendar and Outlook contacts.

The UTmail Gmail account forwards into the primary Microsoft 365 mailbox, so Microsoft 365 is the one source that can see both forwarded UTmail and Microsoft-native messages. Syncing the UTmail Gmail inbox as the primary source would either miss archived forwarded copies or duplicate messages already present in Microsoft 365.

## Scope
- Mail is read-only: bounded Inbox snapshots, never send, reply, forward, move, mark read, archive, or delete.
- Calendar is read/write: list calendars, sync a bounded calendar view, find events, create events, and update events.
- Contacts are read/write for the signed-in user's default Outlook Contacts folder: list/find/sync contacts, create contacts, and update contacts.
- Authentication is delegated public-client access as the signed-in user. There are no application-wide permissions and no client secret.

Microsoft Graph's `Mail.Read`, `Calendars.ReadWrite`, `Contacts.ReadWrite`, and `User.Read` delegated permissions are the intended permission boundary. The first implementation gate is whether the UT tenant permits the required app registration and user consent.

## Safety Model
All calendar and contact writes are dry-run by default and require `--execute`. Neither surface exposes delete commands.

Calendar writes are restricted to configured writable calendar IDs. The default calendar may be represented by the stable `primary` alias. Creating or updating an event with attendees can send invitations or meeting updates; attendee-bearing writes therefore require an explicit `--notify` acknowledgement, and the plan must show every resolved address before execution.

Contact writes affect only the signed-in user's default Outlook Contacts folder, not UT's institutional directory. Contact identity resolution must never guess: updates require an exact Graph contact ID, while creates require explicit field values. There is no organization-directory write scope.

Mail, calendar, contact, and profile data are private. Real account configuration and token caches stay in ignored `lifeos-tools/secrets/` files. The public repo contains only fake examples and synthetic fixtures.

## Command Shape
The intended surface is an `m365` command group so Microsoft services remain distinct from the existing Google-specific commands:

```text
lifeos m365 accounts
lifeos m365 auth ALIAS [--no-browser]
lifeos m365 profile ALIAS
lifeos m365 mail sync ALIAS [--qa | --output FILE]
lifeos m365 calendar list-calendars ALIAS
lifeos m365 calendar find ALIAS QUERY [--from DATE] [--to DATE] [--calendar ID] [--json]
lifeos m365 calendar sync ALIAS [--qa | --output FILE]
lifeos m365 calendar create-event ALIAS ... [--notify] [--execute]
lifeos m365 calendar update-event ALIAS --event ID ... [--notify] [--execute]
lifeos m365 contacts list ALIAS [--json]
lifeos m365 contacts find ALIAS QUERY [--json]
lifeos m365 contacts sync ALIAS [--qa | --output FILE]
lifeos m365 contacts create ALIAS ... [--execute]
lifeos m365 contacts update ALIAS --contact ID ... [--execute]
```

Generated snapshots belong under `sources/m365/`, with an index that identifies the account alias and verified Graph profile. Initial sync stays explicit rather than silently expanding the aggregate `lifeos sync` command.

## Authentication And Portability
Use Microsoft's supported authentication library rather than maintaining a second hand-written OAuth implementation. The default path should open the system browser for interactive authorization-code authentication with PKCE; `--no-browser` may use device-code authentication for terminal-only environments. Token caches must be written atomically with private file permissions.

The ignored account config should make tenant, client ID, token-cache path, service enablement, query bounds, and writable calendar IDs explicit. `lifeos doctor` should report configuration and token presence without reading or printing token contents.

## Bounded Data Model
Mail follows the existing Gmail limits unless live use demonstrates a reason to diverge: Inbox only, 30 days, at most 150 messages, and at most 8,000 body characters per message.

Calendar follows the existing LifeOS date window and uses Graph calendar views so recurring occurrences and exceptions appear in the requested range. Calendar descriptions are bounded and HTML is cleaned before Markdown rendering.

Contacts sync is capped and contains stable contact IDs plus selected personal fields needed for retrieval and update. It does not recurse through additional contact folders, ingest the UT organization directory, infer people, or derive relationship data from communications.

## Non-Goals
- Sending or mutating mail.
- Deleting calendar events, calendars, contacts, or contact folders.
- Writing UT directory records or reading the full UT directory.
- Teams, SharePoint, OneDrive, tasks, or group calendars.
- Background daemons, webhooks, subscriptions, or unattended app-only access.
- Automatic cross-provider deduplication or merging M365 calendar events into the Google Calendar snapshot during this spike.

## Validation
Offline tests use synthetic Graph responses and pure rendering/body-building helpers. Live QA starts in `lifeos-tools/qa/`, verifies the signed-in profile before any write, tests read surfaces first, and uses disposable events/contacts for explicit user-approved write tests. No live snapshot or token is committed.

## Sources
- [Microsoft identity platform authentication flows](https://learn.microsoft.com/en-us/entra/identity-platform/authentication-flows-app-scenarios)
- [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)
- [List messages](https://learn.microsoft.com/en-us/graph/api/mailfolder-list-messages?view=graph-rest-1.0)
- [List a calendar view](https://learn.microsoft.com/en-us/graph/api/user-list-calendarview?view=graph-rest-1.0)
- [Create an event](https://learn.microsoft.com/en-us/graph/api/calendar-post-events?view=graph-rest-1.0)
- [Update an event](https://learn.microsoft.com/en-us/graph/api/event-update?view=graph-rest-1.0)
- [List contacts](https://learn.microsoft.com/en-us/graph/api/user-list-contacts?view=graph-rest-1.0)
- [Create a contact](https://learn.microsoft.com/en-us/graph/api/contactfolder-post-contacts?view=graph-rest-1.0)
- [Update a contact](https://learn.microsoft.com/en-us/graph/api/contact-update?view=graph-rest-1.0)
