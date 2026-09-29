# LifeOS Microsoft 365 Mail Archive — To Do
Concept and design: [lifeos-m365-mail-archive.md](lifeos-m365-mail-archive.md). Scope widened 2026-09-29 to Gmail archive and labels plus M365 folders.

## Current State
- Implemented 2026-09-29: M365 folders, list, archive, unarchive, move, create-folder; Gmail labels, list, archive, unarchive, label (`--skip-inbox`), unlabel, create-label. Decision 0007 written, 0004 amended, skills and README updated, offline tests added.
- M365 is live-verified on the UT mailbox. Gmail is verified live for reads, dry runs, and refusals; executed Gmail changes wait on Aslan re-consenting each account for `gmail.modify`.

## To Do
### Phase 0 — Feasibility
- [x] `Mail.ReadWrite` is already in the UT Graph PowerShell effective context; requesting it prompted nothing (2026-09-29).

### Phase 1 — Decision
- [x] `docs/decisions/0007-mail-archive-and-labels.md` amends 0004 and covers Gmail; rejected alternatives recorded. 0004's mail bullet points to it.

### Phase 2 — Command
- [x] M365 `mail folders`, `mail list`, `mail archive`, `mail unarchive`, `mail move`, `mail create-folder`: dry-run default, exact IDs, source rules, refused targets, cap of 50, Graph `$batch`, readback under the new ID.
- [x] Gmail `labels`, `list`, `archive`, `unarchive`, `label [--skip-inbox]`, `unlabel`, `create-label`: user labels only, Trash/Spam refused, readback.
- [x] Shared ignored audit log `lifeos-tools/secrets/logs/mail-writes.jsonl`.
- [x] Opt-in flags `mail.write_enabled` / `gmail.write_enabled` in the ignored account configs (examples default to false). Enabled locally for `ut` (M365) and `personal`, `professional`, `open-austin` (Gmail); Gmail `ut` stays disabled, as before.
- [x] Offline tests: `lifeos-tools/tests/test-mail-triage.sh` (synthetic mailbox; mutation-checked against the refused-target list, `--skip-inbox`, and readback). Full suite green.

### Phase 3 — Docs
- [x] `lifeos-m365`, `lifeos-gmail`, and `lifeos-cli` skills; README commands and prose; `lifeos help`.
- [x] Skills tell vault skills relying on Inbox-only snapshots to record that in `assumes:`.

### Phase 4 — QA
- [x] M365 live round trip, 2026-09-29: one UT Inbox mailchimp message archived (confirmed by readback), then unarchived back to the Inbox under its new ID. Folder refusals and source rules exercised live.
- [ ] Aslan re-consents Gmail: `lifeos google auth personal --docs-write --docs-comment`, `lifeos google auth professional`, `lifeos google auth open-austin --docs-comment`.
- [ ] Gmail live round trip on one low-value thread per account: archive, unarchive; label with `--skip-inbox`, unlabel, unarchive.
- [ ] Human QA by Aslan: spot-check Outlook and Gmail after a real triage pass.

## Open Questions
- Should `mail sync` gain an Archive-folder view, so the vault can still see what was archived? The audit log covers "what did the agent move" for now.
- Is the per-call cap right at 50?
- The vault-side triage skill and its approval model are LifeOS work, tracked in the vault's `docs/TODO.md`, not here. The vault's policy on agents surfacing rather than triaging (vault policy 0003) will need revisiting there.

## Ready For Human QA
- M365 mail folders and moves (live-verified by the agent).

## Done
- [x] Spike sketched and promoted to active (2026-09-29).
- [x] Implementation, decision, docs, tests, M365 live QA (2026-09-29).
