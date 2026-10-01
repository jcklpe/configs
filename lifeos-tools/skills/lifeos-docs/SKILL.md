---
name: lifeos-docs
description: "Use when editing an existing native Google Doc through the lifeos CLI — updating a shared doc, fixing or replacing a line, adding a hyperlink to existing text, or reading a Doc's text and revision id. Covers lifeos docs read, replace-once (one exact uniquely-matched replacement, dry-run by default, revision-guarded; --markdown inserts formatted headings, bullets, bold, and links at that spot), set-body (rewrite a whole tab from Markdown), and docs comments/comment (list comments, or add one comment quoting uniquely occurring text). Creating a new Doc from a local file is lifeos-drive's import-doc instead."
---

# LifeOS Docs
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-docs/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

This is the surface for changing a Doc that **already exists**. Creating a new Doc from a local file is `lifeos drive import-doc` — see `lifeos-drive`. Searching, listing, or reading non-Doc files is also `lifeos-drive`.

## Commands
**This list can fall behind the CLI.** Before telling anyone what `lifeos docs` can or cannot do, run `lifeos help | grep 'docs '` and, if a capability is in question, read `lib/google-docs.py`. Never conclude a capability is missing from this skill's silence.

```sh
lifeos docs read ALIAS DOC_URL_OR_ID [--tab-id ID]... [--show-links]
lifeos docs replace-once ALIAS DOC_URL_OR_ID (--old TEXT | --old-file FILE) (--new TEXT | --new-file FILE) [--tab-id ID]... [--link "TEXT=URL"]... [--markdown] [--execute]
lifeos docs set-body ALIAS DOC_URL_OR_ID (--file FILE | --new MARKDOWN) [--tab-id ID]... [--execute]
lifeos docs comments ALIAS DOC_URL_OR_ID
lifeos docs comment ALIAS DOC_URL_OR_ID [--quote TEXT] (--body TEXT | --body-file FILE) [--tab-id ID]... [--execute]
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

## Formatting
The CLI writes real Doc formatting from Markdown: `#`–`######` headings, `-` bullets, nested bullets (two spaces per level, created as real Google list nesting levels), `**bold**`, `*italic*`, and `[text](url)` links. Two commands use it:

- **`replace-once --markdown`** formats the replacement in place. The matched text is deleted, the Markdown is inserted at that spot, and the inserted paragraphs are reset to normal text first, so they don't inherit the matched paragraph's bullet or heading. Everything else in the Doc is untouched, including people and date chips. This is the right tool for adding a formatted section to a shared Doc: match an anchor line and put that line back as the first line of the Markdown (with `- ` if it was a bullet). `--link` cannot be combined with it; write links in the Markdown. The old text may span several paragraphs (to rewrite a whole section at once), but must not start or end with a newline; a file from `grep` or `printf` ends in one, so strip it. The tool refuses otherwise, because deleting that paragraph break would merge the insert into the neighbouring paragraph. Nested bullets only nest when they are created together with their parent, so rewrite a parent and its children in one call rather than one paragraph at a time.
- **`set-body`** clears a whole tab and rewrites it from Markdown. It keeps the Doc's id, history, and comments, but **it destroys native chips** (people, dates, rich links) and any formatting the Markdown cannot express. Use it on Docs LifeOS generated, not on shared Docs other people or tools have enriched.

Plain `replace-once` (without `--markdown`) uses Google's text replacement, which keeps the surrounding paragraph's style and cannot add headings or bullets.

To see a Doc's existing heading levels and bullets before matching them, read its structure with the Docs API rather than `docs read`, which flattens styles.

## Links
`--link "Visible text=https://…"` embeds a hyperlink on text inside the replacement. Repeatable. Each visible label must occur exactly once in the replacement text, for the same reason the match must be unique.

## Comments
`docs comments` lists a Doc's comments and works with the normal read-only Drive scope. `docs comment` adds one comment and is dry-run by default. It needs the full Drive scope, granted once with `lifeos google auth ALIAS --docs-comment`: the narrower `drive.file` scope only reaches files LifeOS itself created, so it cannot comment on someone else's Doc.

`--quote` must match text that occurs exactly once, the same rule as `replace-once`, and is re-checked against the live Doc before posting. When a value repeats (the same date in two table cells), quote a unique neighbour such as the row label and name both rows in the comment body.

**Google does not anchor API comments to text.** The quote is stored with the comment and shown in it, but the passage is not highlighted in the Doc the way a hand-made comment is. Put enough context in the quote or body that a reader can find the spot.

A comment on a shared Doc is an outward-facing write like any other: show the dry-run plan and get approval for the specific comments before `--execute`.

## Boundaries
- Do not use this to rewrite a document wholesale. It is for bounded, reviewable changes; a wholesale rewrite of a shared doc should be a conversation with its owner first.
- Do not edit a shared or collaborative document without explicit approval for that specific change. Show the dry-run plan and let the user approve it.
- Preserve the document's existing authorship and conventions. Do not append agent minutes to someone else's doc because a transcript was processed elsewhere.
- Keep private context out of shared documents.
- Do not reach for `~/work/org/tools/google-docs/` instead. That tool exists for Open Austin's own workflow and authenticates as the `open-austin` account; it will 403 on documents that account cannot reach. This command is the general one. The duplication is deliberate — see `docs/decisions/0005-docs-editing-in-lifeos-tools.md`.
