---
attention: live
---

# Workflow Reconciliation — Tasks
Opened: 2026-10-25. Slug: `workflow-reconciliation`.

## Background
Apply the user's platform-neutral naming preference, upstream reusable workflow improvements into shared `main`, reconcile both project adaptations, and update their consumers. [Concept and before/after assessment](workflow-reconciliation.md).

## Project Organization
Shared procedure changes belong to Project Workflows `main`, which is now also configs' canonical maintenance/global checkout. Other projects, including Agent Hands, retain their own adaptation branches and metadata. Agent Hands owns its adoption record and exact workflow pin. Configs owns this coordination pair and its two child pins. Outer configs remains on `master`.

## General Principles
Preserve unrelated edits and commits, project-specific configuration, earlier CLI feedback, and existing folder paths. Publish only explicitly scoped refs after reviewing their complete outgoing history. No force-push, credential changes, unrelated branch deletion, or unrelated outer-repository publication. The user separately authorized retiring the configs adaptation with recoverable history; other consumers remain unchanged.

## Current State Overview
The original neutral-branch reconciliation is recorded below as history. The 2026-10-26 follow-up flattens the shared collection, makes configs the canonical shared-main checkout, removes unused env scaffolding and the redundant source notice, and updates installed links/installer routing. The retired configs adaptation is recoverable by its published archive tag. This checkpoint changes only configs' workflow pin; Agent Hands, other consumers, and unrelated outer history remain untouched. Client QA and outer publication remain separate.

## To Do
No local reconciliation work remains. Outer publication and client/closure decisions are outside the completed Git handoff.

## Ready for Human QA
- Confirm the intended agent clients follow the adopted repository routing. Source/link checks and Git clone checks do not establish client discovery or interaction behavior.

## Done
- [x] Inspect actual repository boundaries, remotes, branches, current setup/update guidance, and publication scope. The containing configs repository is on `master`, separate from its workflow adaptation. Refreshed remote inspection confirmed the 50 unrelated outgoing configs commits and the absence of the desired new project refs.
- [x] Rename only the workflow adaptation branches and record matching configuration. Local branches are `project/configs` and `project/agent-hands`; their histories and project settings are preserved. Removed stale old-name Git tracking where present, pending explicit new-ref tracking on publication. No folder or remote-branch deletion occurred.
- [x] Assess the original workflow and check the reusable draft. The concept records the coverage gaps. YAML parsing, selected-diff review, and the independent read-only synthetic exercise passed; the installed quick validator failed at import because PyYAML is unavailable. No runtime dependencies were changed.

- [x] Integrate the reviewed reusable setup/update/README/template changes into shared `main` without project-only configuration. Published the four-file shared change on `main`; its configuration remains neutral and no project branch was merged upstream.

- [x] Merge the accepted shared revision into both adaptation branches and verify project settings, ancestry, and tracking metadata. Both published project branches include accepted shared `main`, differ from it only in their respective `workflow.toml`, and track their matching neutral remote refs. Old remote refs were preserved.

- [x] Update and publish the Agent Hands workflow pin and current routing while preserving its feedback and adoption history. Published the reviewed feedback/adoption/reconciliation range and the verification record. The feedback concept remains byte-for-byte unchanged; the initial branch names survive only as historical context.

- [x] Update the outer configs metadata, current routing, index, and exact child pins without publishing unrelated outgoing commits. This scoped local checkpoint records the published workflow and Agent Hands tips. The containing repository stays on `master`; unrelated history and concurrent work are excluded from publication.

- [x] Verify exact remote refs, fresh recursive consumer retrieval, local outer pins, and scoped final diffs; record remaining limitations. Remote shared/adaptation/consumer refs match their commits. Fresh public recursive retrieval passed for Agent Hands. Configuration, links, ignores, retained customization, and local pin checks passed; the Python validator import failure and client/outer-publication limits remain explicit.

## 2026-10-25 verification record (historical)
The original installed quick-validator command failed with `ModuleNotFoundError: No module named 'yaml'`. An existing Ruby YAML parser successfully read the two changed skills' frontmatter. The synthetic exercise made no repository or network changes and reported no material contradiction in the candidate procedure. These are bounded checks, not a claim that the Python validator ran or that live publication succeeded.

Shared-main ancestry and retained project configuration passed for both adaptations. A fresh public recursive clone fetched Agent Hands and its exact nested Project Workflows pin from their recorded HTTPS URLs without local clone overrides. At that checkpoint, metadata pointed to `project/configs` and `project/agent-hands`; old remote branches had not been deleted.

The outer configs checkpoint updates both exact child pins locally and leaves the prior 50 unrelated outgoing commits intact. Publishing `configs/master` would expose that additional history, so no outer push was attempted. Fresh remote cloning of that unpublished outer tree remains unverified; this does not invalidate the independently verified published Agent Hands consumer. Client routing/interaction QA is still open.

## 2026-10-26 follow-up verification
- [x] Locate and inspect all six selected projects for workflow env files, references, setup requirements, and actual consumers without reading private configuration values. No required dependency was found; existing distinct private-context and credential mechanisms remain intact.
- [x] Flatten all eight complete skill directories and update shared setup/update/template/README routing. Keep ordinary project adaptation policy and document the explicit canonical-installation exception.
- [x] Remove the unused env example/instructions and the source-owner-waived MIT notice; retain ignore guards, generic privacy rules, and the unchanged AGPL license.
- [x] Publish the reviewed shared main change, update configs' exact workflow pin and branch metadata, and reconcile all 16 live workflow links with their explicit installer entries. Preserve the Agent Hands pin and all unrelated edits.
- [x] Preserve the full retired adaptation tip in the published `archive/project-configs-2026-10-26` tag; retire only authorized clean local branch uses and the exact remote branch without force.

The packaged Python quick validator still fails to import PyYAML. Existing Ruby YAML parsing, direct TOML/resource/link checks, asset comparisons, installer shell syntax and isolated idempotent link tests provide bounded validation; no tool dependencies were changed. Exact shared-main and archive-tag remote readback, independent fresh clone retrieval, and final local pin/link checks are recorded in the task handoff. Interactive client behavior remains human QA, and outer configs publication remains blocked by its unrelated outgoing history.

Remote readback and an independent fresh clone both resolve shared `main` to `330ffddf851328401ae3a2869da70b04817394bd`; the published archive tag resolves to the complete retired tip `f7b74a7d9a02539e889cec0415716bc47f5afcdf`. All eight frontmatters and 17 shared local links pass direct checks. The selected parent documents have 105 resolving local links and no newly broken links. The broad parent-link check also found two unchanged, pre-existing links to the retired `lifeos-tools/README.md` and `lifeos-tools/pyproject.toml` in the modular-distribution spike; those belong to the separate service cutover and remain its follow-up.
