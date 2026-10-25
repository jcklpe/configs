# 0007 Mail Archive, Folders, And Labels
## Current Approach
Mail mutations are limited to **reversible filing and metadata changes**, the outbound spam/junk rescue commands below, and the standing rules governed by [0009](0009-mail-filters-and-rules.md). Sending, replying, forwarding, marking read, and one-off deletion remain unavailable. Concretely:

- **Microsoft 365:** `mail archive` (Inbox to Archive), `mail unarchive` (Archive to Inbox), `mail move` (to any allowed folder), and `mail create-folder`, plus the read-only `mail folders` and `mail list`. Deleted Items, Junk Email, Drafts, Sent Items, Outbox, recoverable items, and every folder beneath them are never move targets, because moving there amounts to deleting, spam-reporting, or sending.
- **Gmail:** `archive` and `unarchive` (remove or restore `INBOX`), `label` and `unlabel` for user labels only, `label --skip-inbox` as the folder equivalent, and `create-label`, plus the read-only `labels` and `list`. System labels (`TRASH`, `SPAM`, `UNREAD`, `STARRED`, `IMPORTANT`, categories) cannot be applied or removed, and mail already in Trash or Spam is refused.

Each write surface is **off unless the account opts in**: `mail.write_enabled` in `m365-accounts.json` (which switches the requested scope from `Mail.Read` to `Mail.ReadWrite`) and `gmail.write_enabled` in `google-accounts.json` (which adds `gmail.modify`). Both scopes technically permit more than the CLI exposes (`gmail.modify` can trash; `Mail.ReadWrite` can delete). As in 0004, the control is the deliberately narrow command surface, not the token.

All writes follow the existing write discipline: dry-run by default with `--execute` to apply; exact message or thread IDs only; unknown IDs, wrong-source messages, and ambiguous folder or label names fail the whole call ([0006](0006-writes-fail-rather-than-guess.md)); a per-call cap of 50; readback after every executed change; and a local audit log (`mail-writes.jsonl` beside the owning `use-gmail` or `use-outlook-mail` skill, ignored) of every executed change, including the new ID Microsoft assigns a moved message.

This repository supplies the capability only. What counts as noise, and whether an agent may archive without asking, is policy for the calling vault's skills.

## Rationale
Reversible filing removes repeated manual work while keeping sending and deletion outside the one-off command surface. Per-account opt-in allows one account to stay read-only. Exact IDs, source checks, batch caps, readback, and a local audit log bound mistakes even though the granted provider scopes technically allow broader mutations.

## Operating Notes
- Archive, folder moves, and existing-label or category changes can be reversed from the CLI. Executed changes are traced in the audit log. Folder and label creation do not add deletion commands; a mistaken spam/junk rescue is undone in the mail UI.
- Vault snapshots stay Inbox-only, so archived or skip-inbox mail drops out of the vault's view. That is the point for noise, but a vault skill that reads the snapshot as "everything outstanding" should say so in its `assumes:`.
- Microsoft moves change message IDs. The CLI prints and logs the new ID, and unarchive needs it.
- Enabling Gmail writes needs a browser re-consent per account. Until then, executed changes fail with a 403 and a pointer to `lifeos google auth ALIAS`.

## Spam and Junk Rescue
`gmail spam` and `m365 mail junk` provide explicit reads of mail excluded from ordinary snapshots. `gmail not-spam` removes `SPAM` and adds `INBOX`; its source must be in Spam, never Trash. `m365 mail not-junk` moves a Junk message to the Inbox for ordinary triage. This is the narrow exception to the system-label restriction, and it runs only out of Spam or Junk. Reporting spam and moving mail into Junk remain refused. A mistaken rescue is undone in the mail UI. Review cadence and approval belong to the calling vault's policy; Microsoft `reportMessage` is not part of this capability.

## Outlook Categories
`m365 mail categorize` and `uncategorize` set or remove one Outlook category on exact messages, under the same opt-in, dry-run, exact-ID, readback, and audit gates as moves. Master category-list creation or editing, including colors, is outside this capability.

## Standing Rules and Exceptions
[0009](0009-mail-filters-and-rules.md) permits Gmail filters and Microsoft 365 Inbox rules for filing, with an explicitly authorized Microsoft 365 duplicate-mail rule exception that moves future matches to Deleted Items. That exception requires complete sender and recipient-address conditions and does not permit one-off message deletion.

## Rationale for Limits
- **Full read-write mail** (send, reply, forward, delete, mark-read): not asked for, and each is either irreversible or visible to other people.
- **Search-based bulk commands** ("archive everything from X"): a query that matches more than intended fails silently at scale. The caller resolves a search to exact IDs first, using `mail list` or `gmail list`, and the dry-run plan shows every target.
- **Mark-read on archive:** changes state Aslan reads as a signal, and nothing requires it.
- **Moves to any folder, including Deleted Items:** equivalent to deletion by another name.
- **Unbounded standing automation:** future-mail rules have their own capability and approval boundaries in [0009](0009-mail-filters-and-rules.md).
- **One global switch:** per-account opt-in lets an account stay read-only, as the UT Gmail alias does.

## Links
- [0004 LifeOS Microsoft 365 Access](0004-lifeos-microsoft-365-access.md) — delegated access and transport boundary.
- [0006 Writes Fail Rather Than Guess](0006-writes-fail-rather-than-guess.md)
- [lifeos-m365 skill](../../agent-hands/compat/lifeos/skills/lifeos-m365/SKILL.md)
- [lifeos-gmail skill](../../agent-hands/compat/lifeos/skills/lifeos-gmail/SKILL.md)
- [LifeOS mail archive spike](../active-spikes/lifeos-m365-mail-archive.md)
