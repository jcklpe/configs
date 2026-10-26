# LifeOS Microsoft 365 Mail Archive
Status: active, opened 2026-09-29 at Aslan's request.

## Purpose
Let an agent move Microsoft 365 Inbox messages to the Archive folder, so a pass through the UT mailbox can clear noise (newsletters, event promotions, automated notices already handled) and leave Aslan with a short Inbox. At opening on 2026-09-29, the agent could only triage and point; every filing click was his.

Aslan's framing (2026-09-29): archiving is reversible, so it is low-stakes, and it removes work he currently has to do by hand.

**Scope widened the same day (2026-09-29, Aslan):** besides Microsoft 365 archive, (1) archive for every Gmail account, (2) Microsoft 365 folder listing and filing into folders, and (3) Gmail's equivalent, user labels that can skip the Inbox. Deletion stays out everywhere. The slug stays `lifeos-m365-mail-archive` so commit trailers remain continuous. The in/out lists below are the widened scope; the original design sketch is kept beneath them, with notes where the build departed from it.

## Current Policy and Historical Starting Point
The access rule before this spike kept mail strictly read-only. The implemented filing capability is now governed by [mail filing policy 0007](../policies/0007-mail-archive-and-labels.md) and the current [Microsoft 365 access policy 0004](../policies/0004-lifeos-microsoft-365-access.md). As of 2026-10-14, those policies consolidate the current boundaries directly; later standing rules are governed by [0009](../policies/0009-mail-filters-and-rules.md). The implementation scope and design sketch below retain the starting point rather than limiting all later mail capabilities.

## Scope of the September 29 Implementation
In:
- Microsoft 365: `mail folders`, `mail list --folder`, `mail archive` (Inbox to Archive), `mail unarchive`, `mail move --folder`, `mail create-folder`.
- Gmail: `gmail labels`, `gmail list`, `gmail archive`, `gmail unarchive`, `gmail label [--skip-inbox]`, `gmail unlabel`, `gmail create-label`.
- Dry-run by default, `--execute` to act, exact IDs only, readback, per-call cap of 50, a local audit log, and a per-account opt-in flag.

Outside that initial implementation: send, reply, forward, delete, trash, spam, mark-read, flag, moves into Deleted Items / Junk / Drafts / Sent / Outbox (or their subfolders), Gmail system labels, folder or label rename and delete, and rules or filters.

## Design Sketch
- **Graph call:** `POST /me/messages/{id}/move` with `{"destinationId": "archive"}` (a well-known folder name). The move returns the message under a **new ID**; the command must print and log the new ID so `unarchive` can find it.
- **Targeting:** messages are chosen by the exact Graph message ID. The vault snapshot (`sources/m365/<alias>-mail.md`) already prints `Message ID` per message, so an agent triaging from the snapshot has the IDs it needs. No search-based or "archive everything matching X" command in the first version, in the spirit of [policy 0006](../policies/0006-writes-fail-rather-than-guess.md).
- **Guardrails:** only messages currently in the Inbox; a per-call cap (for example 50); refuse any ID not found, rather than skipping silently.
- **Audit log:** each executed move appends a line (timestamp, alias, old ID, new ID, sender, subject) to a gitignored local log beside its owning Gmail or Outlook Mail capability. Mail content never enters this public repo.
- **Snapshot interplay:** `mail sync` reads only the Inbox, so archived mail drops out of the vault's view. That is the point for noise, but it means the vault loses sight of archived items. Consider an optional Archive-folder sync or a "recently archived" section.

## As Built (2026-09-29)
- **Transport:** every Graph call through PowerShell costs about two seconds, so all per-message work (lookup, move, readback, child-folder listing) goes through Graph JSON `$batch`, 20 requests per call.
- **Folder resolution:** a well-known name, an exact ID, a full path like `Inbox/Receipts`, or a unique display name. Ambiguity fails. The folder tree is walked through `childFolders`. Hidden folders are not listed.
- **Refused targets:** Deleted Items, Junk, Drafts, Sent, Outbox, recoverable items, and everything under them, computed from well-known IDs plus parent links.
- **Source rules:** `archive` requires Inbox; `unarchive` requires Archive; `move` accepts any source. Messages already in the destination fail the call.
- **Gmail** uses `messages/batchModify` for message targets and `threads/{id}/modify` for threads; readback checks every affected message's labels.
- **Opt-in flags:** `mail.write_enabled` switches `Mail.Read` to `Mail.ReadWrite`; `gmail.write_enabled` adds `gmail.modify`. Dry runs and reads work without them.
- **Audit log:** the owning capability’s ignored `mail-writes.jsonl`, separate for Gmail and Outlook Mail, recording old and new IDs.
- **Maintained guidance:** [0007](../policies/0007-mail-archive-and-labels.md) owns mail filing; [0004](../policies/0004-lifeos-microsoft-365-access.md) owns the current access boundary.

## Auth
Moving mail needs the delegated `Mail.ReadWrite` scope instead of `Mail.Read`. **Answered 2026-09-29:** the Graph PowerShell shared client's effective context for the UT alias already included `Mail.ReadWrite`, and requesting it produced no prompt or admin-consent gate (unlike `Files.ReadWrite`; see `docs/archive/lifeos-m365.md`). Gmail needs a browser re-consent per account to add `gmail.modify`.

## Where Judgment Lives
This repo supplies the capability only. **What counts as noise, and whether an agent may archive without asking, is LifeOS policy and belongs in a vault skill**, not here (the public-repo rule: no LifeOS content in configs). The vault side is a separate piece of work: likely a `triage-ut-inbox` skill with categories that are safe to archive, and an approval model (a slate in chat at first, maybe standing categories later).

## Related
- [Policy 0004](../policies/0004-lifeos-microsoft-365-access.md): current delegated access and capability boundaries.
- [Policy 0006](../policies/0006-writes-fail-rather-than-guess.md): writes fail rather than guess.
- `docs/archive/lifeos-m365.md`: the original M365 spike and the tenant authorization findings.
- `agent-hands/use-outlook-mail/` and `authorize-microsoft/`: current command and transport owners.
