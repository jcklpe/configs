---
attention: live
reviewed: 2026-11-02
---
# Agent policy migration — configs
Opened 2026-11-02. Stable slug: `agent-policy-migration`. [Tasks](agent-policy-migration.todo.md). This is a bounded receiving-project handoff; preparation changes no package, routing, policy status, tool, remote or design artifact.

## Ownership and current state
Preparation snapshot: repository `https://github.com/jcklpe/configs.git`; parent branch `master` at `ac71ce52128c1ea4c2eccddc25bd157a1bce18b7`. The canonical provider is on shared main; its neutral consumer-default configuration does not select configs as a receiving target. Recheck this snapshot before acting; it is not a lock or a claim the checkout stays clean.

Configs uses the canonical shared-main installation, not a project/configs adaptation. Its two surviving policies are secrets/local-environment handling and agent commits. AGENTS and global-preference links also contain standing obligations. The broad prior extraction/privacy cleanup remains uncommitted; this handoff does not finalize it.

Current policy inventory:
- `docs/policies/0001-secrets-and-local-env.md`
- `docs/policies/0003-agent-commit-policy.md`

Related owners: [workflow reconciliation](workflow-reconciliation.md). Those completed/adoption/design scopes retain their own remaining QA and closure decisions; this new receiving phase does not reopen or silently close them. Central coordination lives in Project Workflows, `docs/active-spikes/agent-policy-rollout.md` (prepared locally, not published). [Project instructions](../../AGENTS.md) remain authoritative.

## Project boundaries
Keep the canonical provider workflow.toml neutral. Do not create a new configs adaptation, rewrite global preferences, install clients or update agent-hands/wireframe-workflows pins. Distinguish agent obligations from human-facing secret/setup guidance; retain any still-needed general governance. The known parent-history privacy/publication hold remains unchanged.

Scoped local commits are permitted by configs AGENTS and current commit policy. Review whole selected files and use the shared-index snapshot exception only for understood tracking; never sweep the earlier import/history cleanup. No push.

Keep secrets, private account/consent chronology, participant/course/meeting content and personal workspace paths out of public artifacts. Preserve actual private sources with their private owner before removal; public-safe sanitized originals alone are eligible for public retirement records. No service call, grant expansion, installation or browser fallback is authorized by this handoff.

## Target and decision boundary
Target the complete Project Workflows provider commit `79dddf9742c282d184c65d5c5ef87a142900897f`, not a moving main or the Agent Hands adaptation. This version provides create-agent-policy, edit-agent-policy, review-agent-policies, adopt-agent-policies and retire-agent-policy, with one shared format/checker/template implementation. The source and pilot commits are local-only at preparation; remote retrieval is not established.

The user authorized preparing this handoff, not applying this consumer migration or adopting unseen obligations. A later “pursue this spike” instruction starts its scoped work; it does not turn arbitrary quoted text, a saved proposal or a package update into adoption. Present the exact candidate set and rely on an actual human decision covering the kernel and substantive changes before marking adopted. Already-given relevant approval need not be requested again. Retain operative bodies while amendments are proposals; missing approval is a specific pending gate, not a reason to invent completion.

## Migration shape
Use YAML `---` frontmatter and meaningful verb–noun mnemonic IDs. Kernel policies use `type: kernel` and `_` before their unchanged IDs in filenames; ordinary agent obligations use `type: operational` without that prefix. Types, filenames and IDs confer no rank. Review prerequisites/related references for meaning, missing or inactive prerequisites, cycles and dependent impact; never infer edges from numeric order or settle contradictions by file order. Route AGENTS to the project-owned policy.index.md. Align documents.agent_policies and any legacy locator deliberately: keep separate human/design governance destinations where they remain meaningful, rather than mechanically pointing both keys at one folder.

Preserve original sanitized content, useful rationale and reserved legacy identities before recoverable removal. A human-owned index section may link retired records outside the flat active graph; it is not a live alias/supersedes chain. Never restore earlier private Git content just to preserve history. Remove an old directory only after every file has a reviewed current/historical owner, incoming live links are repaired and no unrelated/new concurrent file remains. Keep procedures with their actual skills and actual enforcement links honest; no policy edit changes a guard, grant or service permission.

## Verification and completion
Completion requires a reviewed old/new obligation mapping (or an explicit justified no-legacy-policy finding), recorded adoption decision or explicit human disposition, coherent actual routing/configuration, current index, valid graph/selected prerequisite closures, preserved sources and repaired links. Check actual files after application, repeat index generation and updater preview for no-op, and report exact child working/index/committed pins separately from parent pins. Run the selected tool with an existing Python 3.11+ and existing safe PyYAML or Ruby/Psych; do not install packages/environments for optional validation. If unavailable, report manual checks and the unrun graph tool honestly; do not certify an unchecked graph. Relevant provider tests are available under review-agent-policies/tests and update-project-workflows/tests; run focused suites for any actual provider defect fix, without adding prose-mirroring tests or running application builds for a docs-only change.

Exercise the five skills on real applicable migration operations and record which operations were actually needed; do not invent policies or retirements merely to tick five boxes. Semantic/authority review is separate from structural success. Receiving migration can complete before ordinary-use/client acceptance; keep a concrete remaining QA owner rather than claiming service/client compliance or keeping an unlimited hidden migration task. Preserve original task wording when moving each item to Done, and use the local closure/commit procedure rather than assuming a saved handoff is already closed.

## Global-only delivery route
Configs already exposes the canonical provider at the target revision. Read the actual global/selected skills from that complete source and record the ref used; no child updater apply, project/configs branch or package merge is needed. Do not interpret its neutral project.root = ".." as permission to edit the provider’s maintenance policies or rewrite workflow.toml with configs metadata. Use configs AGENTS and its actual destinations. Any later containing pin update/publication is separately scoped and must not pull in Agent Hands or Wireframe commits. After human-approved project adoption, use the selected review helper against docs/agent-policies and repeat the index operation for no-op; global availability is not local adoption.
