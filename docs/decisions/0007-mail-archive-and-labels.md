# 0007 Mail Archive, Folders, And Labels
## Context
[Decision 0004](0004-lifeos-microsoft-365-access.md) made Microsoft 365 mail strictly read-only: "no mail send, reply, forward, move, mark-read, archive, or delete commands." The Gmail tooling was read-only by convention, stated in the `lifeos-gmail` skill rather than a decision record.

That left an agent able to triage a mailbox and point at noise, while every click to clear it stayed with Aslan. On 2026-09-29 he asked for archiving on the UT Microsoft 365 mailbox and on every Gmail account, for Microsoft 365 folder listing and filing, and for Gmail's equivalent, labels that skip the Inbox. His framing: archiving is reversible and so low-stakes, and it removes work he currently does by hand. He also said explicitly that deletion stays out.

The feasibility question for Microsoft 365 was the scope. `Files.ReadWrite` had previously hit an admin-consent wall in UT's tenant. On 2026-09-29 the Graph PowerShell shared client's effective context for the UT alias already included `Mail.ReadWrite`, and requesting it produced no prompt.

## Decision
Mail stays read-only except for **moving mail between folders or labels, in ways that can be undone from the same CLI**. Concretely:

- **Microsoft 365:** `mail archive` (Inbox to Archive), `mail unarchive` (Archive to Inbox), `mail move` (to any allowed folder), and `mail create-folder`, plus the read-only `mail folders` and `mail list`. Deleted Items, Junk Email, Drafts, Sent Items, Outbox, recoverable items, and every folder beneath them are never move targets, because moving there amounts to deleting, spam-reporting, or sending.
- **Gmail:** `archive` and `unarchive` (remove or restore `INBOX`), `label` and `unlabel` for user labels only, `label --skip-inbox` as the folder equivalent, and `create-label`, plus the read-only `labels` and `list`. System labels (`TRASH`, `SPAM`, `UNREAD`, `STARRED`, `IMPORTANT`, categories) cannot be applied or removed, and mail already in Trash or Spam is refused.

Each write surface is **off unless the account opts in**: `mail.write_enabled` in `m365-accounts.json` (which switches the requested scope from `Mail.Read` to `Mail.ReadWrite`) and `gmail.write_enabled` in `google-accounts.json` (which adds `gmail.modify`). Both scopes technically permit more than the CLI exposes (`gmail.modify` can trash; `Mail.ReadWrite` can delete). As in 0004, the control is the deliberately narrow command surface, not the token.

All writes follow the existing write discipline: dry-run by default with `--execute` to apply; exact message or thread IDs only; unknown IDs, wrong-source messages, and ambiguous folder or label names fail the whole call ([0006](0006-writes-fail-rather-than-guess.md)); a per-call cap of 50; readback after every executed change; and a local audit log (`lifeos-tools/secrets/logs/mail-writes.jsonl`, ignored) of every executed change, including the new ID Microsoft assigns a moved message.

This repo supplies the capability only. What counts as noise, and whether an agent may archive without asking, is policy for the calling vault's skills.

### Addendum 2026-09-29: Spam And Junk Rescue
Aslan asked the same day for a way to review spam and mark messages as not spam, off by default but checked regularly. Spam and Junk are never synced, so a misfiled real message is otherwise invisible. Added: `gmail spam` and `gmail not-spam` (remove `SPAM`, add `INBOX`; source must be in Spam, never Trash), and `m365 mail junk` and `mail not-junk` (a Junk-to-Inbox move; source must be Junk). This is the one exception to "system labels cannot be changed", and it runs only *out of* Spam. Reporting spam, and moves into Junk, remain refused, because a false positive there hides real mail. That is also why a mistaken rescue is undone in the mail UI, not the CLI. How often to review Spam and whether a rescue needs approval are vault policy.

### Addendum 2026-09-30: Outlook Categories
Aslan asked for the email-triage tag vocabulary to apply to Microsoft 365 mail too. Added `m365 mail categorize` / `uncategorize`: set or remove one Outlook category on exact messages. Categories are metadata like Gmail user labels, so they fall under this record's "labels" allowance. Same gates as moves. Creating or editing the mailbox's master category list (colors) is not included; it would need the `MailboxSettings` scope.

On Junk, Aslan confirmed on 2026-09-30 that rescued mail belongs in the Inbox to be triaged like any other item, which is what `not-junk` does. Reporting to Microsoft (`reportMessage`) was not wanted.

## Rejected Alternatives
- **Full read-write mail** (send, reply, forward, delete, mark-read): not asked for, and each is either irreversible or visible to other people.
- **Search-based bulk commands** ("archive everything from X"): a query that matches more than intended fails silently at scale. The caller resolves a search to exact IDs first, using `mail list` or `gmail list`, and the dry-run plan shows every target.
- **Mark-read on archive:** changes state Aslan reads as a signal, and nothing requires it.
- **Moves to any folder, including Deleted Items:** equivalent to deletion by another name.
- **Gmail filters or Outlook rules:** standing automation acting on future mail is a different class of risk from acting on mail that has been looked at, and would need its own record.
- **One global switch:** per-account opt-in lets an account stay read-only, as the UT Gmail alias does.

## Consequences
- An agent can now clear or file mail directly, and every such change can be reversed from the CLI and is traced in the audit log.
- Vault snapshots stay Inbox-only, so archived or skip-inbox mail drops out of the vault's view. That is the point for noise, but a vault skill that reads the snapshot as "everything outstanding" should say so in its `assumes:`.
- Microsoft moves change message IDs. The CLI prints and logs the new ID, and unarchive needs it.
- Enabling Gmail writes needs a browser re-consent per account. Until then, executed changes fail with a 403 and a pointer to `lifeos google auth ALIAS`.

## Links
- [0004 LifeOS Microsoft 365 Access](0004-lifeos-microsoft-365-access.md), amended by this record for mail.
- [0006 Writes Fail Rather Than Guess](0006-writes-fail-rather-than-guess.md)
- [lifeos-m365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md)
- [lifeos-gmail skill](../../lifeos-tools/skills/lifeos-gmail/SKILL.md)
- [LifeOS mail archive spike](../active-spikes/lifeos-m365-mail-archive.md)
