# 0008 LifeOS Microsoft 365 Planner
## Current Approach
Use `lifeos m365 planner` as an opt-in surface per account alias, configured with a `planner` block in `m365-accounts.json`.

- **Reads:** `plans`, `buckets`, `tasks` (filters `--bucket`, `--mine`, `--open`), and `task` (with description and checklist).
- **Scopes:** an alias with Planner enabled always requests `Tasks.ReadWrite`, plus `User.ReadBasic.All` so assignee IDs render as names. UT blocks user consent (the same wall `Files.ReadWrite` hit before admin consent on 2026-09-18), and `Tasks.ReadWrite` is already approved for the shared client while `Tasks.Read` is not, so requesting the narrower scope would stall on an admin-approval prompt. Write safety therefore lives in the CLI: `planner.write_enabled`, the plan allowlist, and dry-run-by-default.
- **Snapshot:** `planner sync` writes the plans listed in `planner.plans` to `sources/m365/<alias>-planner.md`, open tasks grouped by bucket and completed tasks in a compact list. Only configured plans are snapshotted, so the vault does not quietly grow to every plan the account can see.
- **Aggregate sync:** `lifeos sync` runs `planner sync` for each alias with `planner.enabled`, at least one configured plan, and `planner.sync` not set to false. Other Microsoft 365 snapshots stay out of the aggregate sync; calendar reads join the combined agenda as described in [0004](0004-lifeos-microsoft-365-access.md).
- **Writes:** `create-task` and `update-task` (title, bucket, due date, progress, assign and unassign, description). They run only when the alias sets `planner.write_enabled`. Writes are dry-run by default, need `--execute`, and are limited to plans in `planner.plans`. Each update sends `If-Match` with the etag read at the start of that run, so a task someone changed in between is refused rather than overwritten. Every executed write is read back and appended to the audit log (`secrets/logs/mail-writes.jsonl`, service `m365-planner`).
- **No delete**, and no comment command: Planner comments live in group conversations, which is a different and broader surface.

## Rationale
Configured team plans need to be ordinary local context, with bounded task updates when authorized. The implementation targets basic Planner plans. In the managed tenant, the shared Graph PowerShell client has approved `Tasks.ReadWrite` while narrower `Tasks.Read` consent is unavailable; CLI opt-in, the plan allowlist, dry-run execution, and ETag guards therefore provide the write boundary.

## Operating Notes
- The configured team plan becomes ordinary vault context, refreshed with the rest of `lifeos sync`.
- The plan is shared with the whole team, so any write is visible to them. The dry-run plan says so, and vault skills should treat Planner writes as outward-facing.
- The etag guard protects within one run; it cannot detect changes made between a dry run and a later `--execute`, which re-reads the task and shows its current state again.
- Enabling Planner adds `Tasks.ReadWrite` and `User.ReadBasic.All` to the requested scopes. Any change to the requested set needs one interactive `lifeos m365 auth ALIAS` (run in a real terminal; `--no-browser` uses a device code) before Planner calls work; until then they stall waiting for sign-in.

## Rationale for Limits
- **Requesting `Tasks.Read` for read-only aliases.** Tried first on 2026-10-02: it is the narrower scope, but in UT's tenant it needs admin approval that has not been granted, so sign-in stalled.
- **Snapshotting every plan from `/me/planner/plans`.** Unbounded, and pulls in boards unrelated to any LifeOS thread.
- **Sending all of Microsoft 365 through the aggregate sync.** Not asked for; mail and calendar have their own established paths.

## Experimental Move Extension
The experimental extension provides dry-run-first `move-task --task ID --plan ID --bucket ID` using the [documented Graph beta task update](https://learn.microsoft.com/en-us/graph/api/plannertask-update?view=graph-rest-beta). The current implementation limits moves to two allowlisted plans in the same Microsoft 365 group, validates bucket membership, refuses active labels, recurrence and externally sourced tasks, and uses one ETag-guarded PATCH. It audits the attempt and verifies the destination and supported preserved fields. It never clones or deletes tasks and never retries an ambiguous write. Goals, custom columns and linked meeting notes remain outside verification. Offline tests are available. Same-group moves were validated live on 2026-10-11 with readback confirming task IDs, descriptions, assignments, dates, progress, priority and destinations. Nonempty checklist/reference and conversation preservation remains unverified live.

## Links
- [LifeOS Microsoft 365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md)
- [0004 LifeOS Microsoft 365 Access](0004-lifeos-microsoft-365-access.md)
- [0006 Writes Fail Rather Than Guess](0006-writes-fail-rather-than-guess.md)
- [0007 Mail Archive, Folders, And Labels](0007-mail-archive-and-labels.md)
