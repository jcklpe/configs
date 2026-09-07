# LifeOS Drive Download

Add a bounded `lifeos drive download` command so the CLI can pull **binary** Drive files (`.pdf`, `.docx`, `.png`, `.xlsx`, …) and export native Google files to a local path. Today `lifeos drive read` only renders native Google Docs/Sheets as text and returns *metadata only* for everything else, which leaves agents unable to inspect the contents of PDFs, Word docs, images, and spreadsheets that live on a shared Drive.

## Why now
A document-review task on a shared Drive stalled on exactly this gap: the files that mattered — Word documents, PDFs, images — are all binary, and the only Drive connector that can reach that shared Drive is this CLI (via its account alias). The Google Drive MCP connector is bound to a different account with no access to the shared Drive in question, so there was no path to read those files at all. The fix belongs in the CLI, which already authenticates as the account that *can* see them.

## Goals
- One new read-side command: `lifeos drive download ALIAS FILE_URL_OR_ID [--out PATH] [--mime EXPORT_MIME] [--force]`.
- Works on **shared drives** (must pass `supportsAllDrives=true`).
- Binary files download byte-for-byte via `files/{id}?alt=media`.
- Native Google files export via `files/{id}/export` with a sensible default target format, overridable with `--mime`.
- Safe by default: never overwrite an existing file without `--force`; write only where the user points it.

## Non-goals
- No new OAuth scope. `drive.readonly` is already granted and is sufficient for both `alt=media` and `export`. This must not trigger re-auth.
- Not a sync/mirror tool. Still on-demand, one file per call, consistent with the existing "do not clone Drive" boundary in the `lifeos-drive` skill.
- No write/delete/move semantics. `import-doc` remains the only Drive write.

## Design notes
- `download` is a **read** operation conceptually, but unlike `read` it lands bytes on disk rather than rendering text, so it gets its own verb rather than a `read` flag. Keeps `read`'s contract (safe to pipe, text-only) intact.
- Default export map for native types: Doc → PDF, Sheet → XLSX, Slides → PDF, Drawing → PNG. Anything else, or a different target, is `--mime`.
- Output resolution: `--out` may be a file path or an existing directory (file lands inside using its Drive name); with no `--out`, the file lands in the CWD under its Drive name. Native exports get the correct extension appended when missing.
- Failure (no access, unsupported export) removes any partial output file and returns non-zero, so a failed download never leaves a truncated artifact.

## Boundaries / safety
- Read-only against Drive; the only local write is the file the user asked for, at the path they chose.
- No secrets involved beyond the existing account token machinery.

## Validation
- `lifeos drive download <alias> <docx-id>` writes a real `.docx` that opens.
- `--out DIR/` lands the file in the directory under its Drive name.
- Native Doc export produces a readable PDF; `--mime` override produces the requested format.
- Overwrite is refused without `--force`.
