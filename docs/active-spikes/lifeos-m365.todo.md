# LifeOS Microsoft 365 To-Do
## Background
Aslan configured the UTmail Gmail address to forward into the primary Microsoft 365 mailbox. LifeOS now needs a native Microsoft Graph integration rather than routing Microsoft 365 back through Gmail.

## Current State Overview
- Spike scope is mail read-only, calendar read/write, and Outlook contacts read/write.
- Writes will be dry-run by default, explicit with `--execute`, and deletion-free.
- The configs working tree was clean when the spike began on 2026-07-15.
- The original external gate was UT tenant authorization and consent.
- Offline implementation and verification are complete. Direct app registration was tested with the UT account on 2026-07-15 and the tenant returned a 401 "You do not have access" response when `New registration` was selected.
- Microsoft's maintained Graph PowerShell client authenticated successfully. Its context contains a cumulative permission set broader than the four requested scopes; Aslan explicitly accepted that tradeoff on 2026-07-15, with the LifeOS command surface serving as the compensating boundary.
- A safe profile request through Graph PowerShell confirmed the intended UT mailbox. Bounded read-only mail, calendar, and contact QA all succeeded through the CLI transport.
- The Codex Outlook Email and Outlook Calendar connectors were installed and both profile checks successfully reached the intended UT mailbox. They provide immediate agent access to mail and calendar, including calendar writes, but they do not expose Outlook contacts or a reusable credential to the standalone `lifeos` CLI.

## To Do
_No implementation or read-only QA work remains._

## Ready for Human QA
- [ ] Approve and execute one disposable calendar create/update test, including the attendee-notification gate if an attendee is tested.
- [ ] Approve and execute one disposable contact create/update test, then remove the disposable records manually because the CLI intentionally has no delete commands.

## Done
- [x] Adapt `lifeos m365` to the Graph PowerShell transport while retaining the optional custom-client MSAL provider. Added provider-aware auth/request dispatch, PowerShell-owned authentication context, protected request handoff, and doctor/config documentation.
- [x] Run full regression and live read-only QA. Shell and PowerShell syntax passed, every offline fixture passed, provider-aware `lifeos doctor` passed, and bounded mail/calendar/contact snapshots were generated in the ignored QA area.
- [x] Exercise calendar and contact create commands as dry runs. Both rendered the intended plans and made no changes.
- [x] Test Microsoft Graph PowerShell as a first-party CLI transport. Authentication succeeded, `Get-MgContext` reported a cumulative effective scope set broader than the four requested scopes, and Aslan accepted that tradeoff with compensating CLI controls.
- [x] Verify the intended mailbox through a safe Graph PowerShell `/me` profile request without reading mail, calendar events, or contacts.
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
