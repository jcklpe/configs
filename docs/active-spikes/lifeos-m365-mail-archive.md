# LifeOS Microsoft 365 Mail Archive
Status: active, opened 2026-09-29 at Aslan's request.

## Purpose
Let an agent move Microsoft 365 Inbox messages to the Archive folder, so a pass through the UT mailbox can clear noise (newsletters, event promotions, automated notices already handled) and leave Aslan with a short Inbox. Today the agent can only triage and point; every click is his.

Aslan's framing (2026-09-29): archiving is reversible, so it is low-stakes, and it removes work he currently has to do by hand.

## Why This Is A Change Of Rule
[Decision 0004](../decisions/0004-lifeos-microsoft-365-access.md) made mail strictly read-only: "no mail send, reply, forward, move, mark-read, archive, or delete commands." This spike carves out one exception, **move to Archive and back**, and keeps the rest. It needs a new decision record that amends 0004, with the rejected alternatives.

## Scope
In:
- `lifeos m365 mail archive ALIAS --message ID [--message ID ...]` moves Inbox messages to the well-known `archive` folder. Dry-run by default; `--execute` to act.
- `lifeos m365 mail unarchive ALIAS --message ID ...` moves them back to the Inbox, so every archive is undoable from the CLI.
- Readback after each move, confirming the message's new parent folder.

Out, and staying out: send, reply, forward, delete, mark-read, flag, move to any folder other than Archive and Inbox, and rules or filters on the mailbox.

## Design Sketch
- **Graph call:** `POST /me/messages/{id}/move` with `{"destinationId": "archive"}` (a well-known folder name). The move returns the message under a **new ID**; the command must print and log the new ID so `unarchive` can find it.
- **Targeting:** messages are chosen by the exact Graph message ID. The vault snapshot (`sources/m365/<alias>-mail.md`) already prints `Message ID` per message, so an agent triaging from the snapshot has the IDs it needs. No search-based or "archive everything matching X" command in the first version, in the spirit of [decision 0006](../decisions/0006-writes-fail-rather-than-guess.md).
- **Guardrails:** only messages currently in the Inbox; a per-call cap (for example 50); refuse any ID not found, rather than skipping silently.
- **Audit log:** each executed move appends a line (timestamp, alias, old ID, new ID, sender, subject) to a gitignored local log under `lifeos-tools/qa/` or `secrets/`. Mail content never enters this public repo.
- **Snapshot interplay:** `mail sync` reads only the Inbox, so archived mail drops out of the vault's view. That is the point for noise, but it means the vault loses sight of archived items. Consider an optional Archive-folder sync or a "recently archived" section.

## Auth
Moving mail needs the delegated `Mail.ReadWrite` scope instead of `Mail.Read`. Open question: whether the Graph PowerShell shared client's cumulative context in UT's tenant already includes it, or whether requesting it hits an admin-consent gate (as `Files.ReadWrite` did; see `docs/archive/lifeos-m365.md` and the vault's parked M365 Files spike). Test this first, since it decides whether the spike is feasible.

## Where Judgment Lives
This repo supplies the capability only. **What counts as noise, and whether an agent may archive without asking, is LifeOS policy and belongs in a vault skill**, not here (the public-repo rule: no LifeOS content in configs). The vault side is a separate piece of work: likely a `triage-ut-inbox` skill with categories that are safe to archive, and an approval model (a slate in chat at first, maybe standing categories later).

## Related
- [Decision 0004](../decisions/0004-lifeos-microsoft-365-access.md): the read-only rule this amends.
- [Decision 0006](../decisions/0006-writes-fail-rather-than-guess.md): writes fail rather than guess.
- `docs/archive/lifeos-m365.md`: the original M365 spike and the tenant authorization findings.
- `lifeos-tools/lib/m365.sh`, `m365-write.py`, `m365-graph.ps1`: where the command and transport live.
