---
attention: live
---

# Workflow Reconciliation
Opened: 2026-10-25. Slug: `workflow-reconciliation`.

This follow-up makes workflow adaptation branches platform-neutral and carries reusable process improvements through shared `main`, both project branches, and their consuming repositories. The user authorized the naming changes, shared skill/guidance changes, project reconciliation, scoped commits, and normal publication needed to make the resulting pins retrievable. This does not authorize publishing unrelated history, deleting old remote branches, changing credentials, force-pushing, or implementing CLI feedback.

Continues from: docs/active-spikes/modular-skill-distribution.md

## Repository boundaries
The outer configs repository stays on `master`. Its `project-workflows/` submodule uses `project/configs`, renamed from `codex/project-configs`. Agent Hands stays on `main`; its own `project-workflows/` submodule uses `project/agent-hands`, renamed from `codex/project-agent-hands`. These are separate workflow working trees with the same upstream repository. Existing folder paths are already neutral and remain unchanged.

Shared Project Workflows `main` owns generic procedures/templates and neutral defaults. Each adaptation owns its project-specific `workflow.toml`. Agent Hands pins its workflow adaptation. Configs pins both its own workflow adaptation and Agent Hands, so publication and pin verification proceed from the deepest child outward.

## Assessment of the previous update skill
The previous procedure expressed the right principles but did not fully spell out the requested operational cycle. It covered merge-base comparison, semantic reconciliation, retained project differences, focused reusable contributions, parent pins, and remote availability. The gaps mattered when changing several branches and nested consumers together.

| Area | Previous coverage | Change in shared guidance |
| --- | --- | --- |
| Project customization | Explicitly preserve intentional divergence and keep actual project docs outside the workflow child. | Retain that boundary and verify that only deliberate differences remain after merging accepted shared work. |
| Reusable contributions | Separate reusable work from project-only changes; contributions could be proposed separately. | Start from clean shared `main`; reconstruct the reusable part of a mixed commit rather than merging an adaptation or leaking its configuration upstream. |
| Return path | Compare ancestry and use a history-preserving integration. | After actual upstream acceptance, retrieve its exact revision, merge it into every authorized adaptation, and verify ancestry plus retained project settings. A proposal is not accepted `main`. |
| Names and ownership | Setup suggested `codex/project-<slug>`; update did not describe renaming. | Default to `project/<slug>` and distinguish the workflow branch from the parent's branch and folder. Cover name collisions, current metadata, stale Git tracking, and preservation of old remote refs/history. |
| Consumer pins | Commit child changes, then update the immediate parent's gitlink. | Map nested consumers and verify child HEAD, index, and committed pin from the deepest child outward. |
| Publication scope | Require explicit authority and remotely available child commits. | Inspect the complete outgoing range, stop unrelated/private history from riding along, verify exact refs, and handle protection/access failures without bypass. |
| Verification limits | Remote checks and collaborator access were acknowledged. | Separate local checks, shared-main acceptance, remote refs, fresh recursive cloning, and client behavior; record failed checks and bounded follow-up. |

The setup skill, README, and agent-routing template are updated alongside the update skill. The initial project configurations remain separate from the shared commit. This is a focused process correction, not a redesign of the other six project procedures or of provider capabilities.

## Preservation and validation
Retain both adaptations' ancestry, project names, document locations, and provider-independent setup. Preserve the earlier CLI feedback concept and its proposals, plus the initial adoption history. Current routing follows the neutral branch names; historical mentions of the initial names remain identifiable as history.

The installed Python quick validator cannot import PyYAML in its available runtime. No dependency installation or tool repair is part of this change. Direct YAML parsing with an existing runtime, reference checks, TOML checks, scoped diffs, and an independent read-only synthetic exercise provide bounded follow-up; they are not reported as a successful run of the unavailable validator. The synthetic exercise covered mixed upstream/project changes, an existing target branch, protected shared `main`, and unrelated unpublished outer history; it selected the expected preservation and stopping points.

## Publication boundary
At discovery, configs `master` was 50 commits ahead of its refreshed remote. Those commits include work outside this request. Updating its exact pins locally is authorized; publishing the whole existing outgoing range is not. Leave those commits intact and report the outer publication dependency. Verify the independently published Agent Hands consumer recursively rather than pretending that proves remote availability of the unpublished outer configs tree.

The [task record](workflow-reconciliation.todo.md) owns actual progress and verification outcomes. This pair stays live pending the remaining publication/client/closure decisions; no closure is implied by completing the local reconciliation.
