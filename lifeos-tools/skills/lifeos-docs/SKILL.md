---
name: lifeos-docs
description: "Use when editing an existing native Google Doc through the lifeos CLI — updating a shared doc, fixing or replacing a line, adding a hyperlink to existing text, or reading a Doc's text and revision id. Covers lifeos docs read and replace-once: one exact uniquely-matched replacement, dry-run by default, revision-guarded. Creating a new Doc from a local file is lifeos-drive's import-doc instead."
---

# LifeOS Docs
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-docs/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

This is the surface for changing a Doc that **already exists**. Creating a new Doc from a local file is `lifeos drive import-doc` — see `lifeos-drive`. Searching, listing, or reading non-Doc files is also `lifeos-drive`.

## Commands
```sh
lifeos docs read ALIAS DOC_URL_OR_ID [--tab-id ID]... [--show-links]
lifeos docs replace-once ALIAS DOC_URL_OR_ID (--old TEXT | --old-file FILE) (--new TEXT | --new-file FILE) [--tab-id ID]... [--link "TEXT=URL"]... [--execute]
```

`ALIAS` is a normal Google account alias (`lifeos google accounts`). This works on **any** Doc any alias can reach — it is not scoped to one project. If a read or write returns `403 PERMISSION_DENIED`, the usual cause is the wrong alias for that document's owner, not a missing capability.

## Safety Model
- **Dry-run by default.** `replace-once` prints its plan and changes nothing without `--execute`.
- **Exactly one match.** The old text must occur exactly once in scope; it refuses with `found 0` or a count otherwise. This is the safety property — it cannot silently hit the wrong paragraph.
- **Revision-guarded.** The write re-fetches the live document and guards on its revision id, so a concurrent human edit fails the write rather than clobbering it.
- **Requires the Docs write scope.** Authorize once per alias: `lifeos google auth ALIAS --docs-write`. Incremental authorization preserves the alias's existing Gmail/Drive scopes. Granting the scope is not authorization to edit — the specific change still needs the user's approval.
- **No delete.** There is no command to remove a Doc.

## Read Before You Write
Always `docs read` first. Two reasons, both learned the hard way:

**Match the document's real characters.** A replacement can fail with `found 0` because the Doc contains a curly apostrophe (`’`) where the command supplied a straight one (`'`). Typographic punctuation, non-breaking spaces, and en/em dashes are the usual culprits. Use `--old-file` with a heredoc rather than embedding prose in a shell argument — this also avoids the shell expanding `$`, backticks, and quotes inside user-authored text.

**The read collapses some structure.** Mailto-linked names can render as empty, so anchor replacements on text you can actually see in the read output.

## Replace-Only, So Inserts Need An Anchor
`replace-once` only replaces. To *insert* a line, replace an anchor line with itself plus the new content:

```sh
printf '%s\n' 'The existing anchor line.' > /tmp/old.txt
printf '%s\n' 'The existing anchor line.' 'The new line being inserted.' > /tmp/new.txt
lifeos docs replace-once ut "$DOC_URL" --old-file /tmp/old.txt --new-file /tmp/new.txt
```

It also cannot write into an **empty** document — there is no anchor to match. Create content with `lifeos drive import-doc`, then edit it here.

## Links
`--link "Visible text=https://…"` embeds a hyperlink on text inside the replacement. Repeatable. Each visible label must occur exactly once in the replacement text, for the same reason the match must be unique.

## Boundaries
- Do not use this to rewrite a document wholesale. It is for bounded, reviewable changes; a wholesale rewrite of a shared doc should be a conversation with its owner first.
- Do not edit a shared or collaborative document without explicit approval for that specific change. Show the dry-run plan and let the user approve it.
- Preserve the document's existing authorship and conventions. Do not append agent minutes to someone else's doc because a transcript was processed elsewhere.
- Keep private context out of shared documents.
- Do not reach for `~/work/org/tools/google-docs/` instead. That tool exists for Open Austin's own workflow and authenticates as the `open-austin` account; it will 403 on documents that account cannot reach. This command is the general one. The duplication is deliberate — see `docs/decisions/0005-docs-editing-in-lifeos-tools.md`.
