# 0009 Mail Filters And Inbox Rules
## Context
Email triage in the LifeOS vault tags recurring mail by hand on every pass: automated work notices get a `work` category in the Microsoft 365 mailbox, bank statements get `delete-me`, and so on. Aslan asked on 2026-10-02 to set up standing rules from the CLI so that sorting happens on arrival. [0007](0007-mail-archive-and-labels.md) and the Gmail skill ruled out filter and mailbox-rule commands until a decision record allowed them.

Standing rules are riskier than one-off label changes: they act on future mail nobody has seen, and both providers' rule systems can forward, redirect, delete, or mark mail read, which is how mailbox compromise usually hides itself.

## Decision
Add rule management to both mail surfaces, limited to filing actions.

- **Gmail filters:** `gmail filters` lists them (read scope). `gmail create-filter` matches on `--from`, `--to`, `--subject`, and `--query`, and may only add one user label and skip the Inbox. `gmail delete-filter` removes a filter by ID. Changes need `gmail.filters_enabled`, which adds the `gmail.settings.basic` scope at the next `lifeos google auth ALIAS`.
- **Microsoft 365 Inbox rules:** `m365 mail rules` lists them. `m365 mail create-rule` matches on `--from`, `--sender-contains`, and `--subject-contains`, and may only assign an Outlook category, move to an allowed folder (the same refused targets as mail moves: Deleted Items, Junk, Drafts, Sent, Outbox and their subfolders), and stop processing further rules. `m365 mail delete-rule` removes a rule by ID. Changes need `mail.rules_enabled`, which adds `MailboxSettings.ReadWrite` at the next `lifeos m365 auth ALIAS`.
- **No forward, redirect, delete, mark-read, or reply action** can be expressed. Listing still shows such actions on rules made elsewhere, so they stay visible.
- Creates and deletes are dry-run by default and need `--execute`. A Gmail dry run also searches recent mail with the equivalent query and shows what the filter would have caught. Every executed change is read back (a created rule must match, and must carry no forward, redirect, or delete action; a deleted one must be gone) and appended to the mail audit log.
- Deleting a rule is allowed, unlike deleting mail, because it removes only the rule and can be recreated; without it a mistaken filter would be stuck until someone found it in the web settings.

## Consequences
- Triage can turn a recurring pattern into a standing rule, and the vault's triage skill decides when to propose one. Each new rule is still an approval item.
- Rules apply to new mail only. Neither provider applies them retroactively through this CLI, so existing mail is still filed with the label and move commands.
- Enabling either flag changes the requested scope set and needs one interactive sign-in. On UT, `MailboxSettings.ReadWrite` is already approved for the shared Graph PowerShell client, so that sign-in should not hit the admin-approval wall that `Tasks.Read` did (see [0008](0008-lifeos-m365-planner.md)).

## Links
- [0007 Mail Archive, Folders, And Labels](0007-mail-archive-and-labels.md)
- [0006 Writes Fail Rather Than Guess](0006-writes-fail-rather-than-guess.md)
- [LifeOS Gmail skill](../../lifeos-tools/skills/lifeos-gmail/SKILL.md)
- [LifeOS Microsoft 365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md)
