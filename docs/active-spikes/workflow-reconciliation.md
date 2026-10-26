---
attention: live
---

# Workflow Reconciliation
Opened: 2026-10-25. Slug: `workflow-reconciliation`.

This follow-up makes workflow adaptation branches platform-neutral and carries reusable process improvements through shared `main`, both project branches, and their consuming repositories. The user authorized the naming changes, shared skill/guidance changes, project reconciliation, scoped commits, and normal publication needed to make the resulting pins retrievable. The later 2026-10-26 scope authorizes flattening the shared skills, removing unused workflow-env scaffolding and the owner-waived MIT source notice, making configs the canonical shared-main installation, and retiring its adaptation with recovery history preserved. It does not authorize publishing unrelated history, changing credentials, force-pushing, implementing CLI feedback, or migrating the other inspected projects.

Continues from: docs/active-spikes/modular-skill-distribution.md

## Repository boundaries
The outer configs repository stays on `master`. Its `project-workflows/` submodule is the canonical maintenance/global installation on shared `main`. The former `project/configs` adaptation (earlier `codex/project-configs`) is retired with its full tip preserved by Project Workflows tag `archive/project-configs-2026-10-26`. Agent Hands stays on `main`; its own `project-workflows/` submodule uses `project/agent-hands`, renamed from `codex/project-agent-hands`. These are separate workflow working trees with the same upstream repository. The collection folder remains `project-workflows/`; its seven current procedures and two compatibility routes now live directly at that root. Agent Hands remains at its existing nested revision and older layout.

Shared Project Workflows `main` owns generic procedures/templates and neutral defaults. Each ordinary adaptation owns its project-specific `workflow.toml`, including projects that have not yet diverged. Configs is the designated canonical exception and retains neutral shared defaults. Agent Hands pins its workflow adaptation; configs independently pins shared workflows and Agent Hands. This cleanup changes only the workflow pin, leaving the Agent Hands gitlink and working files alone.

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
The initial reconciliation retained both adaptations' ancestry, project names, document locations, and provider-independent setup. The canonical follow-up preserves the retired configs history in its archive tag and leaves other adaptations unchanged. Preserve the earlier CLI feedback concept and its proposals, plus the initial adoption history. Current routing follows the neutral branch names; historical mentions of the initial names remain identifiable as history.

The installed Python quick validator cannot import PyYAML in its available runtime. No dependency installation or tool repair is part of this change. Direct YAML parsing with an existing runtime, reference checks, TOML checks, scoped diffs, and an independent read-only synthetic exercise provide bounded follow-up; they are not reported as a successful run of the unavailable validator. The synthetic exercise covered mixed upstream/project changes, an existing target branch, protected shared `main`, and unrelated unpublished outer history; it selected the expected preservation and stopping points.

## Publication boundary
At discovery, configs `master` was 50 commits ahead of its refreshed remote. Those commits include work outside this request. Updating its exact pins locally is authorized; publishing the whole existing outgoing range is not. Leave those commits intact and report the outer publication dependency. Verify the independently published Agent Hands consumer recursively rather than pretending that proves remote availability of the unpublished outer configs tree.

The [task record](workflow-reconciliation.todo.md) owns actual progress and verification outcomes. This pair stays live pending the remaining publication/client/closure decisions; no closure is implied by completing the local reconciliation.

## Canonical installation and layout follow-up
The user clarified that configs is the canonical source for the global workflow links, not an ordinary project adaptation. Inspection found only four adoption-metadata values different from shared main; all procedures were identical. Four historical commits remained unique by ancestry, so retirement preserves the complete old tip rather than claiming there was no unique history. Ordinary projects continue to get adaptation branches at adoption.

The dependency review covered all six requested existing projects. No real workflow env file, variable consumer, or required loader was found. Some projects have separate private-reference or credential mechanisms; those remain untouched. The shared example and its mandatory-sounding setup prose are removed, while generic private-context rules and ignore guards remain. No private configuration values or source contents are copied into public records.

All eight complete skill directories move from `skills/` to the collection root. Shared docs/templates, configs routing and three compatibility wrappers, the 16 explicit installer calls, and the 16 existing workflow links across both clients move together. The six operational procedures and their supporting assets are preserved. The source owner's explicit waiver covers removal of the retained configs MIT notice; the AGPL license remains unchanged. Other consumers retain their old pins and require their own later routing/adoption update.

## Capture for Later
The user approved replacing the separate pinning and future-idea procedures with `capture-for-later`. It saves a possibility or deliberately parked subject in a visible individual scratch note, with only `status: captured` or `status: parked` as the default metadata. The same subject may change state; infrastructure, design, content, features, and other project subjects share this procedure. One sentence is sufficient, and optional rationale or revisit conditions come only from actual context. Capture does not authorize a plan, task list, backlog commitment, or active spike.

The former skill names remain thin source and installed compatibility routes to the new behavior. Their competing definitions, list templates, and old client metadata are retired. Setup, triage, spike routing, the neutral configuration, and local authoring guidance use the new default. Existing notes, list entries, history, and other project checkouts remain untouched; a matching old entry is updated rather than duplicated, with migration reserved for a separate request.
