---
name: lifeos-drive
description: "Use when reading Google Drive on-demand or importing a doc through the lifeos CLI: drive search/list/meta/read, and the dry-run-by-default import-doc write. On-demand only — do not clone or index whole Drives. Uses the shared Google account aliases (set up via lifeos-cli)."
---

# LifeOS Drive
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-drive/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

Drive uses the shared Google account-alias system — set up aliases with `lifeos google accounts` / `lifeos google auth ALIAS` (see `lifeos-cli`).

## Reads
```sh
lifeos drive accounts
lifeos drive search ALIAS "query text"
lifeos drive list ALIAS FOLDER_ID
lifeos drive meta ALIAS FILE_URL_OR_ID
lifeos drive read ALIAS FILE_URL_OR_ID
```

Drive reads are on-demand. Do not clone Drive into LifeOS, recursively index whole Drives, or generate broad Drive summaries. Use `drive search`, then `drive meta` or `drive read` on a specific file. `drive read` supports Google Docs text and bounded Google Sheets previews.

## Import (the only write)
```sh
lifeos drive import-doc ALIAS SOURCE_FILE --title TITLE [--folder FOLDER_ID] [--execute]
```

`import-doc` is the only approved Drive write. It imports a local source file (`.html`, `.md`, `.txt`, `.rtf`, `.doc`, `.docx`) as a native Google Doc, is **dry-run by default**, and only writes with `--execute`. Use it only when the user explicitly asks to create/import a Drive document. Prefer `--folder FOLDER_ID` so the doc lands in the intended location. Do not edit, delete, move, share, or bulk-create Drive files unless a bounded command exists and the user explicitly asks for that specific action.
