---
name: lifeos-drive
description: "Use when reading Google Drive on-demand or importing a doc through the lifeos CLI: drive search/list/meta/read, and the dry-run-by-default import-doc write. On-demand only — do not clone or index whole Drives. Uses the shared Google account aliases (set up via lifeos-cli)."
---

# LifeOS Drive
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-drive/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

Drive uses the shared Google account-alias system — set up aliases with `lifeos google accounts` / `lifeos google auth ALIAS` (see `lifeos-cli`).

To **edit** an existing native Google Doc, use `lifeos docs` — a separate command group with its own skill, **`lifeos-docs`**. Editing does not live under `drive`. This skill covers reading Drive and *creating* a Doc from a local file; changing a Doc that already exists is `lifeos-docs`.

## Reads
```sh
lifeos drive accounts
lifeos drive search ALIAS "query text"
lifeos drive list ALIAS FOLDER_ID
lifeos drive meta ALIAS FILE_URL_OR_ID
lifeos drive read ALIAS FILE_URL_OR_ID
lifeos drive download ALIAS FILE_URL_OR_ID [--out PATH] [--mime EXPORT_MIME] [--force]
```

Drive reads are on-demand. Do not clone Drive into LifeOS, recursively index whole Drives, or generate broad Drive summaries. Use `drive search`, then `drive meta` or `drive read` on a specific file. `drive read` supports Google Docs text and bounded Google Sheets previews.

Use `drive download` when a file is **not** a native Google Doc/Sheet — `.pdf`, `.docx`, `.xlsx`, `.png`, etc. — which `drive read` can only show as metadata. It fetches binaries byte-for-byte and exports native Google files (Doc→PDF, Sheet→XLSX, Slides→PDF, Drawing→PNG by default; override with `--mime`). `--out` accepts a file path or an existing directory (the file lands there under its Drive name); with no `--out` it writes to the CWD. It never overwrites without `--force`, works on shared drives, and adds no OAuth scope. Still on-demand and one file per call — not a mirror/sync; keep the "do not clone Drive" boundary.

## Import (the only write)
```sh
lifeos drive import-doc ALIAS SOURCE_FILE --title TITLE [--folder FOLDER_ID] [--execute]
```

`import-doc` is the only approved `drive` write (it *creates* a Doc). It imports a local source file (`.html`, `.md`, `.txt`, `.rtf`, `.doc`, `.docx`) as a native Google Doc, is **dry-run by default**, and only writes with `--execute`. The plan prints an `Upload type:` line showing the MIME type the file will be sent as — read it, because that is what determines whether formatting survives.

**Markdown converts semantically.** `.md` and `.markdown` upload as `text/markdown`, which Drive turns into real Doc structure: Heading 1/2/3, bulleted and numbered lists, tables, bold and italic. Verified end to end 2026-09-06. `.txt` remains `text/plain`, which imports the characters literally — so do **not** rename a Markdown file to `.txt`, and do not pre-convert Markdown to HTML with pandoc "to be safe." Both produce worse results than passing the `.md` directly. Use it only when the user explicitly asks to create/import a Drive document. Prefer `--folder FOLDER_ID` so the doc lands in the intended location. Do not delete, move, share, or bulk-create Drive files unless a bounded command exists and the user explicitly asks for that specific action.

## Editing an existing Doc
Not here. `lifeos docs read` and `lifeos docs replace-once` own that, and the **`lifeos-docs`** skill covers them — the safety model, the exact-match requirement, and the punctuation and empty-document gotchas that make a first attempt fail.

`drive import-doc` *creates*; `docs replace-once` *changes*. Reach for this skill only when the Doc does not exist yet.
