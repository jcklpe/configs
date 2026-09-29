# LifeOS Microsoft 365 Mail Archive
Status: active, opened 2026-09-29 at Aslan's request.

## Purpose
Let an agent move Microsoft 365 Inbox messages to the Archive folder, so a pass through the UT mailbox can clear noise (newsletters, event promotions, automated notices already handled) and leave Aslan with a short Inbox. Today the agent can only triage and point; every click is his.

Aslan's framing (2026-09-29): archiving is reversible, so it is low-stakes, and it removes work he currently has to do by hand.

**Scope widened the same day (2026-09-29, Aslan):** besides Microsoft 365 archive, (1) archive for every Gmail account, (2) Microsoft 365 folder listing and filing into folders, and (3) Gmail's equivalent, user labels that can skip the Inbox. Deletion stays out everywhere. The slug stays `lifeos-m365-mail-archive` so commit trailers remain continuous. The in/out lists below are the widened scope; the original design sketch is kept beneath them, with notes where the build departed from it.

## Why This Is A Change Of Rule
[Decision 0004](../decisions/0004-lifeos-microsoft-365-access.md) made mail strictly read-only: "no mail send, reply, forward, move, mark-read, archive, or delete commands." This spike carves out one exception, **move to Archive and back**, and keeps the rest. It needs a new decision record that amends 0004, with the rejected alternatives.

## Scope
In:
- Microsoft 365: `mail folders`, `mail list --folder`, `mail archive` (Inbox to Archive), `mail unarchive`, `mail move --folder`, `mail create-folder`.
- Gmail: `gmail labels`, `gmail list`, `gmail archive`, `gmail unarchive`, `gmail label [--skip-inbox]`, `gmail unlabel`, `gmail create-label`.
- Dry-run by default, `--execute` to act, exact IDs only, readback, per-call cap of 50, a local audit log, and a per-account opt-in flag.

Out, and staying out: send, reply, forward, delete, trash, spam, mark-read, flag, moves into Deleted Items / Junk / Drafts / Sent / Outbox (or their subfolders), Gmail system labels, folder or label rename and delete, and rules or filters.

## Design Sketch
- **Graph call:** `POST /me/messages/{id}/move` with `{"destinationId": "archive"}` (a well-known folder name). The move returns the message under a **new ID**; the command must print and log the new ID so `unarchive` can find it.
- **Targeting:** messages are chosen by the exact Graph message ID. The vault snapshot (`sources/m365/<alias>-mail.md`) already prints `Message ID` per message, so an agent triaging from the snapshot has the IDs it needs. No search-based or "archive everything matching X" command in the first version, in the spirit of [decision 0006](../decisions/0006-writes-fail-rather-than-guess.md).
- **Guardrails:** only messages currently in the Inbox; a per-call cap (for example 50); refuse any ID not found, rather than skipping silently.
- **Audit log:** each executed move appends a line (timestamp, alias, old ID, new ID, sender, subject) to a gitignored local log under `lifeos-tools/qa/` or `secrets/`. Mail content never enters this public repo.
- **Snapshot interplay:** `mail sync` reads only the Inbox, so archived mail drops out of the vault's view. That is the point for noise, but it means the vault loses sight of archived items. Consider an optional Archive-folder sync or a "recently archived" section.

## As Built (2026-09-29)
- **Transport:** every Graph call through PowerShell costs about two seconds, so all per-message work (lookup, move, readback, child-folder listing) goes through Graph JSON `$batch`, 20 requests per call.
- **Folder resolution:** a well-known name, an exact ID, a full path like `Inbox/Receipts`, or a unique display name. Ambiguity fails. The folder tree is walked through `childFolders`. Hidden folders are not listed.
- **Refused targets:** Deleted Items, Junk, Drafts, Sent, Outbox, recoverable items, and everything under them, computed from well-known IDs plus parent links.
- **Source rules:** `archive` requires Inbox; `unarchive` requires Archive; `move` accepts any source. Messages already in the destination fail the call.
- **Gmail** uses `messages/batchModify` for message targets and `threads/{id}/modify` for threads; readback checks every affected message's labels.
- **Opt-in flags:** `mail.write_enabled` switches `Mail.Read` to `Mail.ReadWrite`; `gmail.write_enabled` adds `gmail.modify`. Dry runs and reads work without them.
- **Audit log:** `lifeos-tools/secrets/logs/mail-writes.jsonl` (ignored), shared by both services, recording old and new IDs.
- **Decision:** [0007](../decisions/0007-mail-archive-and-labels.md) amends 0004.

## Auth
Moving mail needs the delegated `Mail.ReadWrite` scope instead of `Mail.Read`. **Answered 2026-09-29:** the Graph PowerShell shared client's effective context for the UT alias already included `Mail.ReadWrite`, and requesting it produced no prompt or admin-consent gate (unlike `Files.ReadWrite`; see `docs/archive/lifeos-m365.md`). Gmail needs a browser re-consent per account to add `gmail.modify`.

## Where Judgment Lives
This repo supplies the capability only. **What counts as noise, and whether an agent may archive without asking, is LifeOS policy and belongs in a vault skill**, not here (the public-repo rule: no LifeOS content in configs). The vault side is a separate piece of work: likely a `triage-ut-inbox` skill with categories that are safe to archive, and an approval model (a slate in chat at first, maybe standing categories later).

## Related
- [Decision 0004](../decisions/0004-lifeos-microsoft-365-access.md): the read-only rule this amends.
- [Decision 0006](../decisions/0006-writes-fail-rather-than-guess.md): writes fail rather than guess.
- `docs/archive/lifeos-m365.md`: the original M365 spike and the tenant authorization findings.
- `lifeos-tools/lib/m365.sh`, `m365-write.py`, `m365-graph.ps1`: where the command and transport live.
