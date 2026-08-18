# 0005 Google Docs Editing Lives In lifeos-tools (Duplicated From The Org Repo)
## Context
Editing an existing native Google Doc (bounded, exact, revision-guarded `replace-once`, plus `read`) was available only inside the Open Austin `~/work/org` repo's `tools/google-docs/` tooling, which its `process-weekly-meeting` skill depends on. The `open-austin` Google token already carries the `documents` write scope (decision-adjacent to the `lifeos google auth --docs-write` work).

Because that capability was **not** surfaced in the lifeos CLI — and the `lifeos-drive` skill explicitly said "no existing-Doc edit command" — agents repeatedly concluded Google Docs were read-only under lifeos and failed to make edits the user asked for (including on docs, like an ACT bylaws agenda, that have nothing to do with Open Austin).

A prior decision ("Open Austin Tool Boundary") deliberately removed a duplicate *issue-write* command from the private lifeos adapter and routed skills to the org repo's tools. That was right for issue-writing, which is Open-Austin-specific. Doc editing is different: it is **general-purpose**, and requiring an Open Austin repo checkout to edit any Google Doc is wrong.

## Decision
Add a general-purpose `lifeos docs read` / `lifeos docs replace-once` command to lifeos-tools (`lib/google-docs.py` + shell wiring in `lib/google.sh` and `lifeos.sh`), authenticating through the normal per-alias token machinery (`_google_access_token`; token supplied to the port via `GOOGLE_ACCESS_TOKEN`). It preserves the safety model: dry-run by default, `--execute` to write, exact unique match, revision guard, `--link` support.

- This is an explicit, documented **exception** to the Open Austin Tool Boundary, limited to **doc editing** (a general capability). GitHub **issue** writing/editing stays org-repo-only for now — there is no current need to edit issues outside the Open Austin context.
- The org repo keeps its own copy of the docs tool so it stays self-contained when pulled down standalone. The resulting small code duplication is an **accepted cost**.
- **The org repo must not reference lifeos or personal tooling.** It is a shared repo that others pull down; its agents must get up to speed with no external context. All record of this exception lives here in `configs/`, never in `~/work/org`.

Actual edits remain owned by the consuming workflow's approval rules (`draft-approval-slate`, `process-weekly-meeting`); this decision is about discoverability and generality of the capability, not loosening approval.
