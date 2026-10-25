# 0004 LifeOS Microsoft 365 Access
## Current Approach
Use `lifeos m365` for delegated Microsoft Graph access as the signed-in user, through configured account aliases.

The permission and capability boundary is:

- `User.Read` verifies the authenticated mailbox identity.
- `Mail.Read` supports bounded Inbox snapshots and on-demand folder listing, mailbox search, and full-message reads, including Archive and Sent Items. Mailbox-wide searches exclude Junk Email unless it is requested explicitly. Opt-in mail moves and categories use `Mail.ReadWrite`; [mail filing](0007-mail-archive-and-labels.md) owns those commands and spam/junk rescue. [Filters and Inbox rules](0009-mail-filters-and-rules.md) own standing automation and its narrow duplicate-mail exception. There is no one-off mail send, reply, forward, mark-read, or delete command.
- `Calendars.ReadWrite` supports bounded calendar views and event create/update. Writes are dry-run by default, require `--execute`, are restricted to configured writable calendar IDs, and expose no delete command.
- `Contacts.ReadWrite` supports the default Outlook Contacts folder plus contact create/update. Writes are dry-run by default, require `--execute`, require exact contact IDs for updates, and expose no delete command.
- [Planner access](0008-lifeos-m365-planner.md) and [file writes](0010-lifeos-m365-file-writes.md) have separate opt-in capability boundaries.

Use Microsoft's supported Graph PowerShell client as the default transport. Its effective context in the managed UT tenant can contain a broader cumulative set of previously consented permissions than the scopes this command requests. This transport tradeoff was explicitly accepted on 2026-07-15. Controls live in the narrow LifeOS command surface: no generic Graph request or raw-token command, opt-in write capabilities, dry-run-gated execution, and bounded targets.

PowerShell owns its protected CurrentUser authentication cache. A dedicated public-client application through MSAL is an optional fallback when an application ID is approved. There is no client secret, unattended daemon, or app-only access. Real alias configuration and authentication caches are local-only; only fake examples and synthetic fixtures are tracked.

Microsoft 365 attendee-bearing event writes require `--notify` as acknowledgement that Microsoft may send invitations or meeting updates. This flag does not provide Google's server-side notification suppression. Bare attendee names resolve only through the deterministic local alias map; the tool does not search or guess from UT's directory.

Service exports remain independent. Callers select aliases, domains, windows, and destinations explicitly; the legacy aggregate and combined-calendar sync commands are retired. Provider calendar data exports feed the neutral `render-calendar-agenda` skill. Private workspace procedures own combined agenda selection and snapshot destinations; the public tools do not decide which accounts matter for availability.

## Rationale
The Microsoft 365 mailbox can contain both forwarded UTmail and Microsoft-native messages, making it the canonical UT mailbox source. Keeping that source separate from Gmail avoids missing archived forwarded copies or creating forwarding loops. The shared Graph PowerShell client is usable where direct student-owned tenant registration is unavailable; a deliberately narrow command surface bounds the broader effective delegated context.

## Operating Notes
- LifeOS has one canonical UT mailbox source without routing Microsoft 365 back into Gmail or creating a forwarding loop.
- Calendar and contact write access is intentionally broader than read-only integration, but the CLI contains the blast radius through dry runs, explicit execution, allowlisted calendars, attendee acknowledgement, exact contact IDs, and the absence of delete commands.
- The Graph PowerShell shared client has a broader effective delegated context than LifeOS needs in this tenant. The accepted mitigation is a deliberately narrow, auditable LifeOS command surface rather than abandoning the workable native CLI route.
- The initial contact surface covers only the default Outlook Contacts folder. Additional contact folders can be considered later if actual use demonstrates the need.
- The initial M365 calendar surface does not mutate recurring series as a unit and blocks description replacement on online meetings to avoid damaging embedded Teams meeting data.

## Source and History
[Microsoft 365 implementation](../archive/lifeos-m365.md) and [unified calendar implementation](../archive/unified-calendar.md) retain the development history. Current operational mechanics live in the [Microsoft 365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md) and [calendar skill](../../lifeos-tools/skills/lifeos-calendar/SKILL.md).

## Links
- [LifeOS Microsoft 365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md)
- [LifeOS Tools README](../../lifeos-tools/README.md)
- [LifeOS Microsoft 365 spike](../archive/lifeos-m365.md)
- [0001 Secrets And Local Env Hygiene](0001-secrets-and-local-env.md)
- [0002 LifeOS Calendar Writes And Attendee Resolution](0002-lifeos-calendar-writes.md)
