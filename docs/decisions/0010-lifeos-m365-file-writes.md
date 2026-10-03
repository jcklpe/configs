# 0010 LifeOS Microsoft 365 File Writes
## Context
The `lifeos m365 files` surface was read-only: search, resolve a sharing link, metadata, download. Agents could only change UT OneDrive or SharePoint files through the locally synced copies, which do not include files other people share. On 2026-10-02 Aslan asked for direct writes.

The shared Graph PowerShell client's tenant-wide consent in UT includes `Files.ReadWrite.All` (checked 2026-10-02 against the client's admin grant). UT blocks user consent, and the narrower `Files.ReadWrite` is not in that grant, which is why the earlier `Files.ReadWrite` request hit an admin-approval wall. Delegated access is still bounded by the signed-in user's own permissions: nothing he cannot edit in the browser can be edited through the CLI.

## Decision
Add three write commands to `lifeos m365 files`, behind a per-alias `files.write_enabled` flag:

- **`upload`** puts a new local file into a folder (item ID or `root`, with `--drive` for SharePoint or another user's drive). It refuses when the name already exists (`conflictBehavior=fail`), so it can never overwrite.
- **`replace`** changes an existing file's contents. It sends `If-Match` with the eTag read in the same run, so a file someone changed in between is refused rather than overwritten. OneDrive and SharePoint version history keeps the previous version restorable.
- **`create-folder`** makes a new folder, refusing an existing name.

Every command is dry-run by default and prints the destination path, its current state, and a reminder that others with access will see the change. Executed writes are read back (name and size must match the local file) and appended to the audit log (`secrets/logs/mail-writes.jsonl`, service `m365-files`). Uploads use Graph's simple upload, capped at 250 MB.

Files mode now requests `Files.ReadWrite.All`, the scope UT has approved; the CLI's own surface is the narrower boundary.

**Not included:** delete, move, rename, and any sharing or permission change. **OneNote is refused:** notebooks and `.one`/`.onetoc2` files cannot be safely written by replacing files, and UT has approved no OneNote (`Notes.*`) permission, so OneNote pages stay unreadable and unwritable through the CLI.

The PowerShell transport gains an `input_file` request field so uploads send raw bytes (`Invoke-MgGraphRequest -InputFilePath`); the MSAL path uses `curl --upload-file`. Neither adds a generic request or raw-token command.

## Consequences
- Agents can deliver files straight into shared institutional folders, such as a team deliverable into a SharePoint library or an edited document back into OneDrive, without depending on local sync.
- Shared files are other people's records too. Vault skills treat every executed file write as outward-facing and approval-gated per change, and the shared-record permissions in the LifeOS vault still govern documents registered there.
- Changing the requested scope set requires one interactive `lifeos m365 auth ALIAS`.

## Links
- [0004 LifeOS Microsoft 365 Access](0004-lifeos-microsoft-365-access.md)
- [0006 Writes Fail Rather Than Guess](0006-writes-fail-rather-than-guess.md)
- [0008 LifeOS Microsoft 365 Planner](0008-lifeos-m365-planner.md)
- [LifeOS Microsoft 365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md)
