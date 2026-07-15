# 0004 LifeOS Microsoft 365 Access
## Context
UT provides two institutional email surfaces: a UTmail Gmail address and a Microsoft 365 mailbox. UTmail now forwards into Microsoft 365, making Microsoft 365 the only single source that can contain both forwarded UTmail and Microsoft-native messages.

The existing LifeOS Gmail source is deliberately bounded to current Inbox mail. Treating UTmail as the canonical LifeOS source would miss copies archived by the forwarding rule, duplicate mail already present in Microsoft 365, and still omit Microsoft-native messages.

The user also wants LifeOS to work with the UT calendar and Outlook contacts. Calendar and contact mutations are useful but materially riskier than reads: calendar changes can notify real people, and contact changes alter a durable address book.

## Decision
Add Microsoft 365 as a separate `lifeos m365` command group using delegated Microsoft Graph access as the signed-in user.

The permission and capability boundary is:

- `User.Read` to verify the authenticated mailbox identity.
- `Mail.Read` for bounded read-only Inbox snapshots. There are no mail send, reply, forward, move, mark-read, archive, or delete commands.
- `Calendars.ReadWrite` for bounded calendar views plus event create/update. Writes are dry-run by default, require `--execute`, are restricted to configured writable calendar IDs, and expose no delete command.
- `Contacts.ReadWrite` for the default Outlook Contacts folder plus contact create/update. Writes are dry-run by default, require `--execute`, require exact contact IDs for updates, and expose no delete command.

Use a public-client application and Microsoft's supported MSAL library. There is no client secret, unattended daemon, app-only permission, shared mailbox scope, or organization-directory scope. Real alias configuration and token caches are ignored local files; only fake examples and synthetic fixtures are tracked.

M365 attendee-bearing event writes require `--notify` as an acknowledgement that Microsoft may send invitations or meeting updates. Unlike the Google Calendar path, this flag does not map to a server option that can suppress delivery. Bare attendee names resolve only through the deterministic local alias map; the tool does not search or guess from UT's directory.

Microsoft 365 snapshots remain distinct under `sources/m365/`. They are not silently added to aggregate `lifeos sync`, and M365 calendar data is not merged into the Google Calendar snapshot during the initial implementation.

## Consequences
- LifeOS has one canonical UT mailbox source without routing Microsoft 365 back into Gmail or creating a forwarding loop.
- Calendar and contact write access is intentionally broader than read-only integration, but the CLI contains the blast radius through dry runs, explicit execution, allowlisted calendars, attendee acknowledgement, exact contact IDs, and the absence of delete commands.
- The delegated consent screen is necessarily broader than mail-only access. Live use must stop if UT tenant policy blocks app registration or consent; the answer is not to request app-wide permissions.
- The initial contact surface covers only the default Outlook Contacts folder. Additional contact folders can be considered later if actual use demonstrates the need.
- The initial M365 calendar surface does not mutate recurring series as a unit and blocks description replacement on online meetings to avoid damaging embedded Teams meeting data.

## Links
- [LifeOS Microsoft 365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md)
- [LifeOS Tools README](../../lifeos-tools/README.md)
- [LifeOS Microsoft 365 spike](../active-spikes/lifeos-m365.md)
- [0001 Secrets And Local Env Hygiene](0001-secrets-and-local-env.md)
- [0002 LifeOS Calendar Writes And Attendee Resolution](0002-lifeos-calendar-writes.md)
