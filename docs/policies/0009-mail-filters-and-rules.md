# 0009 Mail Filters And Inbox Rules
## Current Approach
Run the documented native entrypoint in [use-gmail](../../agent-hands/use-gmail/SKILL.md) or [use-outlook-mail](../../agent-hands/use-outlook-mail/SKILL.md); command names below are relative to that entrypoint and take an explicit account alias.

Rule management covers filing actions on both mail surfaces, with the narrow Microsoft 365 duplicate-mail exception below.

- **Gmail filters:** `filters` lists them (read scope). `create-filter` matches on `--from`, `--to`, `--subject`, and `--query`, and may only add one user label and skip the Inbox. `delete-filter` removes a filter by ID. Changes need `gmail.filters_enabled`, which adds the `gmail.settings.basic` scope at the next `bash agent-hands/setup-google-services/scripts/authorize auth ALIAS`.
- **Microsoft 365 Inbox rules:** `rules` lists them. `create-rule` matches on `--from`, `--sender-contains`, `--subject-contains`, and `--recipient-contains`, and may assign an Outlook category, move to an allowed folder (the same refused targets as mail moves: Deleted Items, Junk, Drafts, Sent, Outbox and their subfolders), and stop processing further rules. The duplicate-mail exception below adds a bounded `--delete` action. `delete-rule` removes a rule by ID. Changes need `mail.rules_enabled`, which adds `MailboxSettings.ReadWrite` at the next `bash agent-hands/setup-microsoft-services/scripts/authorize auth ALIAS`.
- **No forward, redirect, permanent-delete, mark-read, or reply action** can be expressed. Listing still shows such actions on rules made elsewhere, so they stay visible.
- Creates and deletes are dry-run by default and need `--execute`. A Gmail dry run also searches recent mail with the equivalent query and shows what the filter would have caught. Every executed change is read back (a created rule must match its enabled state, sequence, complete conditions, exceptions, and complete actions; a deleted one must be gone) and appended to the mail audit log. Readback accepts Graph default empty/false fields and case-insensitive condition normalization, but refuses omitted or broadened predicates and unexpected actions.
- Deleting a rule is allowed, unlike deleting mail, because it removes only the rule and can be recreated; without it a mistaken filter would be stuck until someone found it in the web settings.

## Rationale
Standing rules reduce repeated filing work but act on future messages that nobody has reviewed. The command surface therefore restricts them to filing and the separately bounded duplicate-mail exception. Provider capabilities such as forwarding, permanent deletion, and marking read remain unavailable through this tool.

## Operating Notes
- Triage can turn a recurring pattern into a standing rule, and the vault's triage skill decides when to propose one. Each new rule is still an approval item.
- Rules apply to new mail only. Neither provider applies them retroactively through this CLI, so existing mail is still filed with the label and move commands.
- Enabling either flag changes the requested scope set and needs one interactive sign-in. On UT, `MailboxSettings.ReadWrite` is already approved for the shared Graph PowerShell client, so that sign-in should not hit the admin-approval wall that `Tasks.Read` did (see [0008](0008-lifeos-m365-planner.md)).

## Duplicate-Mail Exception
The exception approved on 2026-10-07 permits a native rule to delete repeated mail delivered to one address while retaining copies delivered to another. Allow `--delete` only when both exact sender selectors (`--from`) and complete recipient-address strings (`--recipient-contains`) are supplied. Microsoft Graph's `delete` action moves messages to Deleted Items; `permanentDelete` remains unavailable. Deletion cannot be mixed with category or folder actions. This authorizes a bounded native-rule capability, not one-off message deletion or autonomous deletion decisions. Every particular standing rule still needs user authorization. Recipient matching covers To and Cc text, rather than resolving aliases to a canonical mailbox identity.

Source: [Microsoft Graph rule predicates](https://learn.microsoft.com/en-us/graph/api/resources/messagerulepredicates?view=graph-rest-1.0), [rule actions](https://learn.microsoft.com/en-us/graph/api/resources/messageruleactions?view=graph-rest-1.0).

## Links
- [0007 Mail Archive, Folders, And Labels](0007-mail-archive-and-labels.md)
- [0006 Writes Fail Rather Than Guess](0006-writes-fail-rather-than-guess.md)
- [Gmail skill](../../agent-hands/use-gmail/SKILL.md)
- [use-outlook-mail skill](../../agent-hands/use-outlook-mail/SKILL.md)
