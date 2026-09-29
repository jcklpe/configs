# LifeOS Microsoft 365 Mail Archive — To Do
Concept and design: [lifeos-m365-mail-archive.md](lifeos-m365-mail-archive.md).

## Current State
- Opened and promoted to active 2026-09-29. Nothing implemented yet.
- The first gate is auth: whether `Mail.ReadWrite` is obtainable for the UT alias.

## To Do
### Phase 0 — Feasibility
- [ ] Check whether the Graph PowerShell context already carries `Mail.ReadWrite`, or request it and record what the UT tenant does (grant, admin-consent prompt, or refusal).
- [ ] If refused: record the finding and park the spike, like the M365 Files spike.

### Phase 1 — Decision
- [ ] Draft `docs/decisions/0007-...` amending 0004: mail stays read-only except move-to-Archive and back. Rejected alternatives: full read-write mail, a search-based bulk archive, mark-read.

### Phase 2 — Command
- [ ] `m365 mail archive` and `mail unarchive`: dry-run default, `--execute`, exact message IDs only, Inbox-only source check, per-call cap, readback of the new parent folder, new ID printed.
- [ ] Gitignored audit log of executed moves.
- [ ] Synthetic-fixture tests alongside the existing m365 tests; no real mail in the repo.
- [ ] `mail.write_enabled`-style opt-in flag in the ignored account config, so archiving is off unless enabled per alias.

### Phase 3 — Docs
- [ ] Update `lifeos-tools/skills/lifeos-m365/SKILL.md`: the archive exception, commands, safety model. Update `lifeos-cli` if its summary of M365 changes.
- [ ] Note in the skill that vault skills relying on the snapshot being Inbox-only should record it in `assumes:`.

### Phase 4 — QA
- [ ] Live round trip on one low-value message: archive, confirm in Outlook, unarchive, confirm back in Inbox.
- [ ] Human QA by Aslan.

## Open Questions
- Should `mail sync` gain an Archive-folder view, so the vault can still see what was archived?
- Is the per-call cap right at 50?
- The vault-side triage skill and its approval model are LifeOS work, tracked in the vault, not here.

## Ready For Human QA
- None yet.

## Done
- [x] Spike sketched and promoted to active (2026-09-29).
