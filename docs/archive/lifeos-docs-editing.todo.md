# LifeOS Docs Editing — To-Do
Implementation state for `docs/active-spikes/lifeos-docs-editing.md`. **Blocked on the scope decision (Option 1/2/3 + the boundary-exception question) — do not implement until Aslan confirms.**

## Background
Doc-editing works via `~/work/org/tools/google-docs/` but is invisible to `lifeos help` and contradicted by the `lifeos-drive` skill text, so agents fail to use it. The `open-austin` Google token already carries the `documents` scope. See the conceptual doc for the Open Austin Tool Boundary tension.

## Current State Overview
- Capability: present but org-repo-bound and undiscoverable from lifeos.
- Decision: **pending Aslan.** Nothing implemented yet.

## Decision (2026-08-18, Aslan)
**Option 1.** Port `docs read` / `replace-once` into lifeos-tools. Doc-editing was pulled out before because the `org/` repo needs it self-contained — but **lifeos-tools needs it too**, and the resulting small code duplication is **an accepted cost**. This is a documented exception to the Open Austin Tool Boundary. Separately: GitHub issue writing/editing *could* also come to lifeos-tools later, but **not now** — Aslan only edits GH issues in the `org/` + Open Austin context, so there's no current need. Keep issue-writing org-only for now.

## To Do
- (empty — implementation, polish, and verification complete; spike ready to archive.)

## Ready for Human QA
- (none — Aslan declined human QA; agent verified `--execute` directly, see Done.)

## Done
- [x] DECISION (Aslan): pick Option 1/2/3 → **Option 1, confirmed 2026-08-18.** Doc-editing to lifeos-tools; accept the small duplication; documented exception to the Open Austin Tool Boundary; issue-writing stays org-only.
- [x] Add `lifeos docs read` and `lifeos docs replace-once` to `lifeos.sh` (subcommand dispatch + arg parsing), wrapping the ported tool. → Added the `docs)` dispatch case in `lifeos.sh`; `_docs_helper` + `_docs_run` in `lib/google.sh`; ported the tool stdlib-only to `lib/google-docs.py`. Preserves dry-run default, `--execute`, `--link`, revision guard, exact-unique-match.
- [x] Wire it to `_google_access_token ALIAS` so it works for any alias. → `_docs_run` resolves the alias to a token and passes it via `GOOGLE_ACCESS_TOKEN`; also normalizes a Doc URL to an ID via `_drive_file_id`.
- [x] Confirm `--docs-write` scope handling. → The port surfaces the raw Google API error if the scope is missing; `lifeos help` + the skill note the `--docs-write` requirement. (A friendlier hint is the optional polish item above.)
- [x] Update `lifeos help` usage block. → Added the two `docs` lines.
- [x] Update the `lifeos-drive` skill. → Replaced the "no existing-Doc edit command" line and added an "Editing an existing Doc" section pointing at `lifeos docs`.
- [x] Update the `lifeos-cli` skill. → Pointed its `--docs-write` note at `lifeos docs replace-once` as the bounded editor.
- [x] Add a decision record. → `docs/decisions/0005-docs-editing-in-lifeos-tools.md` (in configs, **not** the org repo, per Aslan's constraint that org stays free of lifeos references).
- [x] Decide on parity for the org repo copy. → Keep both; org repo untouched and self-contained; duplication accepted and documented here.
- [x] Verified end-to-end from the agent shell (2026-08-18): `lifeos help` lists the commands; `lifeos docs read open-austin <id>` renders the ACT agenda doc; `lifeos docs replace-once <url> ...` dry-runs cleanly (URL→ID extraction works).
- [x] Real `--execute` verified (2026-08-18): net-zero round-trip on the ACT agenda doc (edit a line, then revert it) — both writes succeeded, revision advanced each time, doc restored exactly. Aslan declined human QA and asked the agent to test, since the agent is the primary user.
- [x] Optional polish: on a `replace-once --execute` 403 / insufficient-scope, print a "run `lifeos google auth <alias> --docs-write`" hint (alias passed via `LIFEOS_DOCS_ALIAS`). Done in `lib/google-docs.py` + wrapper.
- [x] Scoped the work and surfaced the Open Austin Tool Boundary tension as the gating decision (2026-08-18). Conceptual + to-do docs created; TODO.md index updated.

## Open Questions
- Should `personal`/`professional` tokens also opt into `--docs-write`, or keep doc-editing to `open-austin` for now?
- Is the small tool-duplication (org repo + lifeos) acceptable, or is Option 3 (shared lib) worth the extra work up front?
