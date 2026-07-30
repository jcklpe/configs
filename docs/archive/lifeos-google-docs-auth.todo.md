# LifeOS Google Docs Authorization To-Do
## To Do
- None.

## Done
- [x] Commit the verified change after Aslan explicitly approves the one unavoidable staging step for the two new spike files. The pre-commit audit found no credential material; personal and Open Austin OAuth tokens and `google-accounts.json` are ignored. — Dropped as written on 2026-07-29: Aslan directed atomic pathspec commits without a separate staging-approval gate; `commit-work` remains authoritative for the exact new-file exception.
- [x] Add an opt-in `--docs-write` scope to the normal `lifeos google auth` flow.
- [x] Document that permission setup does not authorize edits and does not add a generic existing-Doc writer to `lifeos drive`.
- [x] Reauthorize the `personal` LifeOS Google account with `lifeos google auth personal --docs-write` on 2026-07-29. The first callback failed only because the local listener had already exited; restarting the command and opening its fresh link while the listener remained active succeeded.
- [x] Confirm the reauthorized personal token works with the bounded org Google Docs tool by reading a native Doc owned by the personal account. Reading the Open Austin shared Doc with that token correctly returned `PERMISSION_DENIED` because the personal account does not have access; the normal Open Austin token remains the appropriate account for that shared record.
