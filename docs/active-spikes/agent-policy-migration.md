---
attention: live
reviewed: 2026-11-21
---
# Agent policy migration — configs
Opened 2026-11-02. Stable slug: `agent-policy-migration`. [Tasks](agent-policy-migration.todo.md). The user approved D19 on 2026-11-21. All five [project-owned policies](../agent-policies/policy.index.md) are adopted, routing is active, and the two numeric originals are preserved in indexed retirement records. The dated preparation and mapping below explain the migration.

## Ownership and current state
Repository: `https://github.com/jcklpe/configs.git`; canonical branch `master`, local machine branch `morris`. The canonical Project Workflows provider is on published shared `main`; its neutral consumer-default configuration does not select configs as a receiving target. Configs uses its own [target configuration](../project-workflows.toml).

Configs uses the canonical shared-main installation, not a project/configs adaptation. Its adopted operational policies cover secrets/local-environment handling and agent commits. AGENTS and global-preference links also contain standing obligations. Migration delivery is recorded under [Morris reconciliation](morris-reconciliation.md).

Current policy inventory:
- `docs/policies/0001-secrets-and-local-env.md`
- `docs/policies/0003-agent-commit-policy.md`

Related owner: [archived workflow reconciliation](../archive/workflow-reconciliation.md). This migration does not reopen that accepted scope. [Project instructions](../../AGENTS.md) remain authoritative.

## Project boundaries
Keep the canonical provider workflow.toml neutral. Do not create a new configs adaptation, rewrite global preferences, install clients or update agent-hands/wireframe-workflows pins as part of this policy migration. Distinguish agent obligations from human-facing secret/setup guidance; retain still-needed general governance. No publication is included.

Scoped local commits are permitted by configs AGENTS and current commit policy. Review whole selected files and use the shared-index snapshot exception only for understood tracking; preserve unrelated work. No push.

Keep secrets, private account/consent chronology, participant/course/meeting content and personal workspace paths out of public artifacts. Preserve actual private sources with their private owner before removal; public-safe sanitized originals alone are eligible for public retirement records. No service call, grant expansion, installation or browser fallback is authorized by this handoff.

## Preparation record and decision boundary
The selected complete Project Workflows source provides create-agent-policy, edit-agent-policy, review-agent-policies, adopt-agent-policies and retire-agent-policy with one shared format/checker implementation. The canonical checkout matches the published shared source selected by the containing Git pin. The unchanged kernel candidate copies are bound to that source by these SHA-256 content fingerprints:

| Candidate | Source content SHA-256 |
| --- | --- |
| ADOPT-POLICIES | `76e578393077904e0805202ea9d9d45174c6c64fe4e6356a38f6284f3fbfb8c0` |
| PRESERVE-IDENTITY | `fd040d9bf24a9322275cf0a17d4077292492f5ba3ea21535ba0f79188671b212` |
| RESOLVE-DEPENDENCIES | `3a338b416b63e260ed48abae017e2eba31295ab93f3722eee380ddc80e451c86` |

The user authorized pursuing this migration. That permits preparation and review, not adoption of unseen obligations. Present the exact candidate set and rely on an actual human decision covering the kernel and substantive changes before marking adopted. Already-given relevant approval need not be requested again. Retain operative bodies while amendments are proposals.

## Reviewed obligation mapping
| Current owner | Candidate or retained owner | Meaning and impact |
| --- | --- | --- |
| Existing project authority; no adopted policy kernel | Three unchanged kernel candidates | Adds explicit adoption, identity/history and dependency-loading contracts. Does not expand tool or publication permission. |
| `0001` and AGENTS secrets/privacy guidance | PROTECT-SECRETS; retain human setup examples in `docs/policies/` | Retains ignored-before-use, synthetic examples, tool-local secret loading, no private commits and compromised-secret handling. Explicitly bounds cleanup assurances to verified surfaces; this addition awaits adoption. |
| `0003` and AGENTS Git guidance | BOUND-COMMITS | Preserves scoped local checkpoints, review holds, no agent push, no unsolicited rewrite, recovery and overlap checks, no co-author trailers and stable spike handles. Commit Work retains procedure. |
| Global preferences and shell/installer conventions | Existing global/local instructions | No migration or amendment in this set; avoids duplicating unrelated obligations. |

BOUND-COMMITS depends on PROTECT-SECRETS because public-content and ignored-file checks are prerequisites to a checkpoint. The kernel's existing dependency edges retain their source meanings. No edge assigns rank or grants authority.

After adoption, route AGENTS to the local index and applicable adopted prerequisite closures, add `documents.agent_policies = "docs/agent-policies"` to the configs target, and update the existing Git/privacy pointers without copying shared procedures. Preserve the numeric originals in indexed historical records with reserved IDs; retain human-oriented secrets/setup guidance at its current destination. Repair README/TODO and live inbound links in the same adoption change. These routing and retirement changes were applied under D19 on 2026-11-21.

Review used Create for the initial kernel candidates, Edit for mapping existing obligations, Review for semantic/graph checks, Adopt for the exact decision boundary, and Retire for impact planning. No adoption or retirement operation was fabricated merely to exercise a skill. Relevant private workflow concerns informed the review of visible approval text, public-audience checks and precise cleanup claims; their narratives remain private.

On 2026-11-21, an isolated system-temp preview exercised the proposed AGENTS/README/configuration routing and numeric-policy retirement shape. Both original numeric sources were preserved byte-for-byte against their SHA-256 fingerprints, and the proposed TOML parsed with the existing Python runtime. Repeated validation of the actual five proposals passed with an empty operative load list and unchanged index generation. The preview did not alter active routing, retire records or adopt a policy. Exact policy text and migration deltas are ready for the conversational approval slate; temporary preparation is not an approval record.

## Migration shape
Use YAML `---` frontmatter and meaningful verb–noun mnemonic IDs. Kernel policies use `type: kernel` and `_` before their unchanged IDs in filenames; ordinary agent obligations use `type: operational` without that prefix. Types, filenames and IDs confer no rank. Review prerequisites/related references for meaning, missing or inactive prerequisites, cycles and dependent impact; never infer edges from numeric order or settle contradictions by file order. Route AGENTS to the project-owned policy.index.md. Align documents.agent_policies and any legacy locator deliberately: keep separate human/design governance destinations where they remain meaningful, rather than mechanically pointing both keys at one folder.

Preserve original sanitized content, useful rationale and reserved legacy identities before recoverable removal. A human-owned index section may link retired records outside the flat active graph; it is not a live alias/supersedes chain. Never restore earlier private Git content just to preserve history. Remove an old directory only after every file has a reviewed current/historical owner, incoming live links are repaired and no unrelated/new concurrent file remains. Keep procedures with their actual skills and actual enforcement links honest; no policy edit changes a guard, grant or service permission.

## Verification and completion
Completion requires a reviewed old/new obligation mapping (or an explicit justified no-legacy-policy finding), recorded adoption decision or explicit human disposition, coherent actual routing/configuration, current index, valid graph/selected prerequisite closures, preserved sources and repaired links. Check actual files after application, repeat index generation and updater preview for no-op, and report exact child working/index/committed pins separately from parent pins. Run the selected tool with an existing Python 3.11+ and existing safe PyYAML or Ruby/Psych; do not install packages/environments for optional validation. If unavailable, report manual checks and the unrun graph tool honestly; do not certify an unchecked graph. Relevant provider tests are available under review-agent-policies/tests and update-project-workflows/tests; run focused suites for any actual provider defect fix, without adding prose-mirroring tests or running application builds for a docs-only change.

Exercise the five skills on real applicable migration operations and record which operations were actually needed; do not invent policies or retirements merely to tick five boxes. Semantic/authority review is separate from structural success. Receiving migration can complete before ordinary-use/client acceptance; keep a concrete remaining QA owner rather than claiming service/client compliance or keeping an unlimited hidden migration task. Preserve original task wording when moving each item to Done, and use the local closure/commit procedure rather than assuming a saved handoff is already closed.

## Global-only delivery route
Configs already exposes the canonical provider at the target revision. Read the actual global/selected skills from that complete source and record the ref used; no child updater apply, project/configs branch or package merge is needed. Do not interpret its neutral project.root = ".." as permission to edit the provider’s maintenance policies or rewrite workflow.toml with configs metadata. Use configs AGENTS and its actual destinations. Any later containing pin update/publication is separately scoped and must not pull in Agent Hands or Wireframe commits. After human-approved project adoption, use the selected review helper against docs/agent-policies and repeat the index operation for no-op; global availability is not local adoption.
