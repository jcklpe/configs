# 0008 LifeOS Microsoft 365 Planner
## Context
Aslan's campus job tracks team work in a Microsoft Planner plan owned by a Microsoft 365 group. The job is a live LifeOS thread, and agents working on it need that board as local context the same way they read the Trello, calendar, and mail snapshots. He also wants to update tasks on it from the CLI.

A read-only check on 2026-10-02 showed the existing graph-powershell session for the `ut` alias already reaches the plan: its effective delegated context includes `Tasks.ReadWrite` and `Group.Read.All` (the shared Graph PowerShell client's cumulative consent, see [0004](0004-lifeos-microsoft-365-access.md)). The plan is a basic Planner plan, which Microsoft Graph's Planner API covers; Planner Premium plans are not reachable through it.

[0004](0004-lifeos-microsoft-365-access.md) kept Microsoft 365 snapshots out of the aggregate `lifeos sync`.

## Decision
Add `lifeos m365 planner` as an opt-in surface per account alias, configured with a `planner` block in `m365-accounts.json`.

- **Reads:** `plans`, `buckets`, `tasks` (filters `--bucket`, `--mine`, `--open`), and `task` (with description and checklist).
- **Scopes:** an alias with Planner enabled always requests `Tasks.ReadWrite`, plus `User.ReadBasic.All` so assignee IDs render as names. UT blocks user consent (the same wall `Files.ReadWrite` hit before admin consent on 2026-09-18), and `Tasks.ReadWrite` is already approved for the shared client while `Tasks.Read` is not, so requesting the narrower scope would stall on an admin-approval prompt. Write safety therefore lives in the CLI: `planner.write_enabled`, the plan allowlist, and dry-run-by-default.
- **Snapshot:** `planner sync` writes the plans listed in `planner.plans` to `sources/m365/<alias>-planner.md`, open tasks grouped by bucket and completed tasks in a compact list. Only configured plans are snapshotted, so the vault does not quietly grow to every plan the account can see.
- **Aggregate sync (amends 0004):** `lifeos sync` runs `planner sync` for each alias with `planner.enabled`, at least one configured plan, and `planner.sync` not set to false. Other Microsoft 365 snapshots stay out of the aggregate sync.
- **Writes:** `create-task` and `update-task` (title, bucket, due date, progress, assign and unassign, description). They run only when the alias sets `planner.write_enabled`. Writes are dry-run by default, need `--execute`, and are limited to plans in `planner.plans`. Each update sends `If-Match` with the etag read at the start of that run, so a task someone changed in between is refused rather than overwritten. Every executed write is read back and appended to the audit log (`secrets/logs/mail-writes.jsonl`, service `m365-planner`).
- **No delete**, and no comment command: Planner comments live in group conversations, which is a different and broader surface.

## Rejected Alternatives
- **Requesting `Tasks.Read` for read-only aliases.** Tried first on 2026-10-02: it is the narrower scope, but in UT's tenant it needs admin approval that has not been granted, so sign-in stalled.
- **Snapshotting every plan from `/me/planner/plans`.** Unbounded, and pulls in boards unrelated to any LifeOS thread.
- **Sending all of Microsoft 365 through the aggregate sync.** Not asked for; mail and calendar have their own established paths.

## Consequences
- The configured team plan becomes ordinary vault context, refreshed with the rest of `lifeos sync`.
- The plan is shared with the whole team, so any write is visible to them. The dry-run plan says so, and vault skills should treat Planner writes as outward-facing.
- The etag guard protects within one run; it cannot detect changes made between a dry run and a later `--execute`, which re-reads the task and shows its current state again.
- Enabling Planner adds `Tasks.ReadWrite` and `User.ReadBasic.All` to the requested scopes. Any change to the requested set needs one interactive `lifeos m365 auth ALIAS` (run in a real terminal; `--no-browser` uses a device code) before Planner calls work; until then they stall waiting for sign-in.

## Links
- [LifeOS Microsoft 365 skill](../../lifeos-tools/skills/lifeos-m365/SKILL.md)
- [0004 LifeOS Microsoft 365 Access](0004-lifeos-microsoft-365-access.md)
- [0006 Writes Fail Rather Than Guess](0006-writes-fail-rather-than-guess.md)
- [0007 Mail Archive, Folders, And Labels](0007-mail-archive-and-labels.md)
