---
attention: historical
---

# Workflow Reconciliation
Historical record. Closed 2026-11-20. Slug: `workflow-reconciliation`. Current procedure belongs to [Setup Project Workflows](../../project-workflows/setup-project-workflows/SKILL.md), [Update Project Workflows](../../project-workflows/update-project-workflows/SKILL.md) and [configs instructions](../../AGENTS.md#skills-workflow). The selected published delivery and ordinary macOS client acceptance are complete; other consumers and deferred client/platform checks retain their owners.

The retained development entries describe their dated checkpoints; later pending or local-only statements are historical.

Opened: 2026-10-25. Slug: `workflow-reconciliation`.

This follow-up makes workflow adaptation branches platform-neutral and carries reusable process improvements through shared `main`, both project branches, and their consuming repositories. The user authorized the naming changes, shared skill/guidance changes, project reconciliation, scoped commits, and normal publication needed to make the resulting pins retrievable. The later 2026-10-26 scope authorizes flattening the shared skills, removing unused workflow-env scaffolding and the owner-waived MIT source notice, making configs the canonical shared-main installation, and retiring its adaptation with recovery history preserved. It does not authorize publishing unrelated history, changing credentials, force-pushing, implementing CLI feedback, or migrating the other inspected projects.

Continues from: docs/archive/modular-skill-distribution.md

## Final scope and acceptance — 2026-11-20
The selected configs/global workflow installation and Agent Hands adoption are delivered. Configs maintains the unchanged shared source on the child's main branch; Agent Hands selects its exact detached pin. Project-owned settings and policies stay outside the package. Published child retrieval, all recursive pins and installed links have been verified through the installation reconciliation. Ordinary macOS Codex and Claude Code discovery and project-local precedence have user acceptance, and actual repository work follows the declared procedures.

The dated rollout history below does not claim every consumer was published or retested. Remaining changes in other consumers stay with their project-owned records. Windows/Linux validation is deferred until relevant; the separate Copilot instruction-discovery question remains in [configs work](../../TODO.md#later). Receiving configs policy adoption belongs to [Agent policy migration](../active-spikes/agent-policy-migration.md). Other-machine delivery verification remains with [Morris reconciliation](morris-reconciliation.md). None is an unfinished implementation item in this selected workflow delivery.

Current maintenance belongs to [Setup Project Workflows](../../project-workflows/setup-project-workflows/SKILL.md), [Update Project Workflows](../../project-workflows/update-project-workflows/SKILL.md) and [configs instructions](../../AGENTS.md#skills-workflow).

## Repository boundaries
Configs uses canonical `master` with `morris` and `lovelace-homelab` machine branches. Its `project-workflows/` checkout is the canonical maintenance/global installation on shared `main`. Agent Hands uses `main` and pins its own unchanged detached workflow source. Project settings remain outside shared source in the declared `docs/project-workflows.toml`; private overrides remain ignored. The parent Git links record exact revisions.

The former configs adaptation is retained by the published `archive/project-configs-2026-10-26` tag. Earlier adaptation-branch and workflow.toml statements below describe dated delivery history. Current source and configuration procedures belong to the maintained setup/update skills. The [Morris reconciliation history](morris-reconciliation.md) records the selected child-first publication and old-checkout retirement; current maintenance follows the repository README and setup skills. Other consumers are separate.

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

The follow-up decision is a clean cutover: remove the former skill names, their configs wrappers, and their managed installed links. Keep the natural-language pinning and future-idea triggers in `capture-for-later`. Setup, triage, spike routing, the neutral configuration, and local authoring guidance use the new default. Delete the tracked configs pinned-issues document without creating a replacement note or task; its single coordination concern is not an actual issue. The subsequent disposition removes the tracked future-ideas list after preserving three residual service possibilities as small `status: captured` notes in Agent Hands: Trello write previews/readback, Slides reading, and richer Sheets extraction. Current local capabilities and existing notes were checked first; completed, superseded, personal-workflow, and speculative integration material is not promoted into new work. Agent Hands notes are a separate local checkpoint, not a remote publication or an update to its containing gitlink. Historical records and the nested workflow pin remain unchanged.

## Local rollout checkpoint
The subsequent user-approved rollout adopts project branches for Org, ResearchOps, Agentic Wiki, Agent Hands, Texas design, Enzo, and a private synced-storage consumer, following the completed website pilot. Each consumer owns its comparison and verification record. The private consumer's procedures, note content, and recovery details stay private; none are copied here. Plain non-Git folders remain global-skill users without local collections.

Shared guidance now covers separately authorized legacy-register conversion, partial parent scaffolds, and private local recovery. Generic source and consumer changes remain local pending security/privacy review; earlier publication evidence above describes earlier checkpoints only. Configs stays on `master` and its canonical workflow child stays on shared `main` with neutral settings. This checkpoint records both exact child pins and preserves the independently completed Agent Hands onboarding commit.

Local checks cover ancestry, retained project settings, complete skills/resources, YAML/TOML, affected links, preservation of unrelated work, and child/index/committed pins. Private recovery was verified outside synced storage. Wiki and Enzo retain unrelated dirty indexes; Texas has corrected root routing within an existing uncommitted scaffold, so its committed documentation is not yet a full portable setup. Fresh agent-client behavior, security/privacy review, remote availability, and recursive collaborator cloning remain distinct outstanding checks. No push, deployment, credential change, or service implementation change is part of this workflow rollout.
