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
- Authentication is delegated access as the signed-in user through Microsoft Graph PowerShell. There is no client secret or app-only access.

LifeOS asks for Microsoft Graph's `Mail.Read`, `Calendars.ReadWrite`, `Contacts.ReadWrite`, and `User.Read` delegated permissions. The narrower command surface—not the shared client's cumulative effective scope set—is the practical capability boundary for this account.

## Live Authorization Finding
On 2026-07-15, direct registration was tested in the UT Entra tenant. The account could open the App registrations list, but selecting `New registration` returned a 401 "You do not have access" response. Direct student-owned registration inside UT's tenant is therefore unavailable.

Microsoft's maintained Graph PowerShell client provided a workable alternative using Microsoft's shared public client. Interactive authentication succeeded, and a safe `/me` profile request confirmed the intended UT mailbox. Its authenticated context also exposed a large cumulative permission set beyond the four scopes LifeOS requested. Aslan explicitly accepted that pragmatic tradeoff on 2026-07-15 so the native CLI route could proceed.

The Codex Outlook Email and Outlook Calendar connectors were also installed, and read-only profile checks through both connectors reached the intended UT mailbox. They remain useful for in-Codex work but do not expose Outlook contacts or reusable CLI authentication. Graph PowerShell is therefore the standalone `lifeos m365` transport.

The adapter deliberately does not expose a generic Graph request command or raw access tokens. Mail remains read-only; calendar/contact writes retain dry-run, explicit-execution, and no-delete gates. PowerShell owns the protected CurrentUser authentication context. A dedicated least-privilege client remains a possible future improvement, not a prerequisite for use.

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
Use Microsoft's supported Graph PowerShell authentication module rather than maintaining a second hand-written OAuth implementation. The default path opens the system browser, while `--no-browser` uses device-code authentication. PowerShell owns its protected CurrentUser authentication cache; LifeOS does not print raw tokens.

The ignored account config makes the auth provider, tenant, service enablement, query bounds, and writable calendar IDs explicit. `lifeos doctor` reports provider readiness without reading or printing authentication contents. A custom-client MSAL provider remains available if a dedicated client ID is approved later.

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

On 2026-07-15, the provider-aware doctor check passed, the CLI profile matched the intended UT mailbox, and bounded read-only Inbox, calendar, and default-contact snapshots were generated successfully in the ignored QA area. Calendar and contact create commands were also exercised as dry runs and made no changes. Live create/update QA remains intentionally pending explicit approval.

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
