# LifeOS Microsoft 365 To-Do
## Background
Aslan configured the UTmail Gmail address to forward into the primary Microsoft 365 mailbox. LifeOS now needs a native Microsoft Graph integration rather than routing Microsoft 365 back through Gmail.

## Current State Overview
- Spike scope is mail read-only, calendar read/write, and Outlook contacts read/write.
- Writes will be dry-run by default, explicit with `--execute`, and deletion-free.
- The configs working tree was clean when the spike began on 2026-07-15.
- The first external gate is UT tenant authorization and consent.
- Offline implementation and verification are complete. Direct app registration was tested with the UT account on 2026-07-15 and the tenant returned a 401 "You do not have access" response when `New registration` was selected.
- The spike is waiting on a sanctioned registration/consent route. The next technical probe is Microsoft's maintained Graph PowerShell client, which still leaves UT in control of delegated consent; UT support is the escalation path if consent is denied. A separately owned multitenant registration should be considered only if UT explicitly permits it.
- The Codex Outlook Email and Outlook Calendar connectors were installed and both profile checks successfully reached the intended UT mailbox. They provide immediate agent access to mail and calendar, including calendar writes, but they do not expose Outlook contacts or a reusable credential to the standalone `lifeos` CLI.

## To Do
_No offline implementation work remains._

## Ready for Human QA
- [ ] Decide whether connector-backed Codex workflows should become the interim M365 mail/calendar path while the native `lifeos m365` backend remains dormant but available for a future sanctioned client.
- [ ] With approval to install the dependency, test Microsoft's maintained Graph PowerShell client using only `User.Read`, `Mail.Read`, `Calendars.ReadWrite`, and `Contacts.ReadWrite`; record whether UT permits user consent or requires administrator approval.
- [ ] Ask UT Enterprise Technology whether it will register/approve a delegated public-client integration for one user's mailbox, calendar, and default Outlook contacts, or whether it permits a user-owned multitenant app to request those delegated scopes.
- [ ] Once a sanctioned client registration exists, run `lifeos m365 auth ut`; confirm the consent screen requests only profile, mail read, calendar read/write, and contacts read/write access.
- [ ] Verify `profile`, mail/calendar/contact QA snapshots, and confirm the expected UT mailbox identity before any live write.
- [ ] Approve and execute one disposable calendar create/update test, including the attendee-notification gate if an attendee is tested.
- [ ] Approve and execute one disposable contact create/update test, then remove the disposable records manually because the CLI intentionally has no delete commands.

## Done
- [x] Verify the installed Outlook Email and Outlook Calendar connectors. Read-only profile calls from both connectors succeeded against the same intended UT mailbox; no mailbox contents or calendar events were read during this check.
- [x] Test direct application registration with the UT account. The App registrations page was readable, but selecting `New registration` returned a 401 "You do not have access" response, confirming that this account cannot create an app in UT's tenant.
- [x] Add the Microsoft account config example, ignore rules, doctor checks, and delegated auth/token-cache helper. Added ignored per-alias config/token paths, a fake tracked example, MSAL browser/device authentication with atomic private token caches, and redacted doctor checks.
- [x] Add Graph request helpers, verified-profile output, pagination, and actionable error rendering without exposing tokens. Added token-backed JSON requests, bounded next-link pagination, `m365 profile`, and Graph error messages that never print bearer tokens.
- [x] Implement bounded read-only M365 Inbox sync and synthetic renderer fixtures. Added recent-Inbox filtering, count/body caps, cleaned text/HTML rendering, direct Outlook links, and fake mail fixtures.
- [x] Implement calendar list/find/sync reads with expanded calendar-view instances. Added calendar discovery, live ID-oriented find, configured-calendar snapshots, and bounded Graph calendar-view retrieval with recurring instances and exceptions expanded by Graph.
- [x] Implement dry-run-gated calendar create/update writes, writable-calendar enforcement, attendee notification acknowledgement, and pure request-body tests. Added create/update with default dry runs, `--execute`, configured writable IDs, literal/local-alias attendee resolution, mandatory `--notify` acknowledgement for attendee-bearing meetings, no delete, and online-meeting body protection.
- [x] Implement Outlook contact list/find/sync reads. Added bounded reads for the default Outlook Contacts folder with stable Graph IDs and selected contact fields.
- [x] Implement dry-run-gated Outlook contact create/update writes and pure request-body tests. Added exact-ID updates, default dry runs, `--execute`, no deletes, and explicit array-replacement behavior for supplied email/phone values.
- [x] Add the `m365` dispatcher/help surface and keep aggregate `lifeos sync` unchanged. Added the nested mail/calendar/contacts surface without silently adding Microsoft data to the aggregate sync.
- [x] Add a `lifeos-m365` service skill, update `lifeos-cli`, README, context output, and setup documentation. Added and globally activated the Codex/Claude skill, installer-managed symlinks, public-client registration guidance, and `sources/m365/` context routing.
- [x] Run all offline tests plus doctor/help golden or equivalent regression checks. All existing and new shell fixtures pass under macOS Bash 3.2; shell/Python syntax, lockfile sync, help/context routing, doctor, ignore rules, and `git diff --check` pass.
- [x] **Added an unplanned durable decision record.** `docs/decisions/0004-lifeos-microsoft-365-access.md` preserves the canonical-mailbox choice, delegated permission boundary, dry-run/no-delete model, attendee acknowledgement, and initial contact/calendar limits.
- [x] **Removed private identifiers from the public repo before commit.** Spike prose and synthetic fixtures retain the routing and data-shape facts without recording Aslan's real UT addresses.
