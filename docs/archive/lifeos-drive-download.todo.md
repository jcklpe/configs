# LifeOS Drive Download — To Do

## Background
`lifeos drive read` (in `lifeos-tools/lib/google.sh`) renders native Google Docs/Sheets as text and returns metadata-only for binaries. This spike adds `lifeos drive download` to fetch binaries and export native files to disk. Conceptual doc: `docs/active-spikes/lifeos-drive-download.md`.

## Project Organization
- Implementation: `lifeos-tools/lib/google.sh` (`_drive_download` + helpers).
- Dispatch: `lifeos-tools/lifeos.sh` (`drive)` case).
- Docs: `lifeos-tools/skills/lifeos-drive/SKILL.md` (repo-local, authoritative), and the `lifeos drive` usage/help block if present.
- bash 3.2 (macOS) safe: no associative arrays.

## General Principles
- No new OAuth scope; `drive.readonly` covers `alt=media` and `export`.
- `supportsAllDrives=true` on every request (shared drives).
- Never overwrite without `--force`; clean up partial files on failure.

## To Do
- (none)

## Ready for Human QA
- (none)

## Done
- Real-terminal sanity: run `lifeos drive download <alias> <id> --out ~/somewhere/` on your machine and confirm the file opens. All validation below was run from the agent environment against a real shared drive and passed. — **Confirmed de facto 2026-09-07.** Aslan closed this on the grounds that the command has been available since 2026-08-13 and no problem has surfaced. Note the weaker evidence class: this is absence-of-complaint, not a witnessed run.
- Add `_drive_download` and helpers (`_drive_export_default_mime`, `_drive_ext_for_mime`) to `lib/google.sh`. Done: binaries via `files/{id}?alt=media&supportsAllDrives=true`; native via `/export`. Default export map Doc→PDF, Sheet→XLSX, Slides→PDF, Drawing→PNG; `--mime` overrides. Cleans up partial file and returns non-zero on failure.
- Wire `download)` into the `drive)` dispatch in `lifeos.sh`. Done.
- Add `drive download` to the CLI usage/help text if a drive help block exists. Done: added the usage line to the `drive` block in `lifeos.sh`.
- Update `lifeos-tools/skills/lifeos-drive/SKILL.md` Reads section to document `download`. Done: added the command + a paragraph on when to use it and the on-demand boundary.
- Validate against real shared-drive binaries (docx, pdf, png) and a native-doc export. Done: a shared-drive `.docx` → valid "Microsoft Word 2007+"; a `.png` → valid PNG image; several `.pdf` files fetched; native Google Doc export → valid multi-page PDF; overwrite without `--force` refused (rc=1); `supportsAllDrives=true` confirmed necessary and present.
- Unplanned: `bash -n` syntax check on both `lifeos.sh` and `lib/google.sh` passed; kept bash-3.2 safe (no associative arrays).
