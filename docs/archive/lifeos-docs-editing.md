# Spike: LifeOS Docs Editing as a First-Class Capability
Conceptual doc. Status: **complete (Option 1, verified 2026-08-18) — archived.** The durable rule lives in `docs/decisions/0005-docs-editing-in-lifeos-tools.md` and the `lifeos-drive` / `lifeos-cli` skills.

## Purpose
Make Google Docs *editing* a discoverable, general-purpose LifeOS capability, instead of something that only effectively exists inside the Open Austin org repo. Today the capability works but is invisible: agents read `lifeos help`, see only `drive read`/`import-doc`, read the `lifeos-drive` skill line that says "`lifeos drive` itself still does not expose an existing-Doc edit command," and conclude docs are read-only — then fail to make edits the user explicitly asked for. (This spike exists because that failure happened repeatedly.)

## What already exists
- `~/work/org/tools/google-docs/docs.py` (+ `run.sh`): `read` and a revision-guarded `replace-once` (exact, uniquely-matched replacement; **dry-run by default**, `--execute` to write; `--link "label=url"` for embedded links). General-purpose — it edits any doc by ID, not just OA docs.
- The Google account tokens (`personal`, `professional`, `open-austin`) can carry the `documents` write scope via `lifeos google auth ALIAS --docs-write` (shipped 2026-07-29; see `docs/archive/lifeos-google-docs-auth.md`). The `open-austin` token already has it.

## The tension to resolve (KEY — needs Aslan's call)
The **"Open Austin Tool Boundary"** work (see `docs/archive/open-austin-tool-boundary.md`) *deliberately* reduced the private LifeOS adapter and **removed its duplicate write command**, routing skills to the public `~/work/org` issue and Google Docs tools. Adding a doc-edit command back into `lifeos-tools` partially reverses that decision.

The counter-argument (why reopen it): **doc-editing is genuinely general-purpose, not Open-Austin-specific.** It was just used to edit an ACT bylaws-agenda doc that has nothing to do with Open Austin — and requiring a checkout of the Open Austin org repo in order to edit *any* Google Doc is architecturally wrong. The boundary decision was right to de-duplicate *issue-writing* (that is OA-specific); doc-editing may be the case where a lifeos-side command is justified.

So the scope decision is: **is a lifeos-side `docs` command an acceptable, documented exception to the Open Austin Tool Boundary, or should doc-editing stay bound to the org repo?**

## Options
1. **Port into lifeos-tools** as `lifeos docs read` / `lifeos docs replace-once` (dry-run default, revision-guarded, `--execute`, `--link`), sharing the existing google auth. The org repo keeps its own copy so `process-weekly-meeting` stays self-contained when the repo is pulled down standalone — i.e. accept small, *documented* duplication of a general tool. **(Leading option.)**
2. **Reference only:** lifeos skills shell out to `~/work/org/tools/google-docs/`. Rejected-leaning: makes general doc editing depend on the OA repo being present.
3. **Shared library:** extract the docs tool to a shared location both consume. Cleanest long-term, most work.

## Non-goals / boundaries
- Not a generic Drive-mutation surface: no delete/move/share/bulk-create. Keep the bounded model.
- Preserve the safety invariants: exact unique match, revision guard, **dry-run by default**, explicit `--execute`.
- Do **not** re-introduce issue-writing to lifeos — that half of the Open Austin Tool Boundary stays.
- Actual edits remain owned by the consuming workflow's approval rules (e.g. `draft-approval-slate`, `process-weekly-meeting`). This spike is about *discoverability + generality of the capability*, not loosening approval.

## Durable-docs impact (on completion)
- `lifeos help` must list the new command.
- The `lifeos-drive` and `lifeos-cli` skills must stop saying "no edit command exists" and point at it.
- A decision record if Option 1/3 is chosen (it amends the Open Austin Tool Boundary decision).

Continues from: docs/archive/open-austin-tool-boundary.md
Continues from: docs/archive/lifeos-google-docs-auth.md
