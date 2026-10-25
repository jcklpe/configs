---
attention: live
---

# Workflow Reconciliation — Tasks
Opened: 2026-10-25. Slug: `workflow-reconciliation`.

## Background
Apply the user's platform-neutral naming preference, upstream reusable workflow improvements into shared `main`, reconcile both project adaptations, and update their consumers. [Concept and before/after assessment](workflow-reconciliation.md).

## Project Organization
Shared procedure changes belong to Project Workflows `main`; project metadata belongs to `project/configs` and `project/agent-hands` inside their respective workflow submodules. Agent Hands owns its adoption record and exact workflow pin. Configs owns this coordination pair and its two child pins. Outer configs remains on `master`.

## General Principles
Preserve unrelated edits and commits, project-specific configuration, earlier CLI feedback, and existing folder paths. Publish only explicitly scoped refs after reviewing their complete outgoing history. No force-push, remote branch deletion, credential changes, or unrelated outer-repository publication.

## Current State Overview
Shared `main`, both neutral adaptation branches, and Agent Hands are published and verified. A fresh public recursive Agent Hands clone retrieved its exact nested pin. This local configs checkpoint records both updated child pins and current routing; its 50 earlier unrelated unpublished commits remain intact and unpublished. Client QA and outer publication remain separate.

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

## Verification Record
The original installed quick-validator command failed with `ModuleNotFoundError: No module named 'yaml'`. An existing Ruby YAML parser successfully read the two changed skills' frontmatter. The synthetic exercise made no repository or network changes and reported no material contradiction in the candidate procedure. These are bounded checks, not a claim that the Python validator ran or that live publication succeeded.

Shared-main ancestry and retained project configuration passed for both adaptations. A fresh public recursive clone fetched Agent Hands and its exact nested Project Workflows pin from their recorded HTTPS URLs without local clone overrides. Current metadata points to `project/configs` and `project/agent-hands`; old remote branches were not deleted.

The outer configs checkpoint updates both exact child pins locally and leaves the prior 50 unrelated outgoing commits intact. Publishing `configs/master` would expose that additional history, so no outer push was attempted. Fresh remote cloning of that unpublished outer tree remains unverified; this does not invalidate the independently verified published Agent Hands consumer. Client routing/interaction QA is still open.
