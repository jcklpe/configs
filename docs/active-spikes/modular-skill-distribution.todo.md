---
attention: live
opened: 2026-10-24
tags: [skills, cli, distribution]
---

# Modular Skill Distribution — To Do
Slug: `modular-skill-distribution`.

Concept: [modular-skill-distribution.md](modular-skill-distribution.md).

## Background and authorization
Capture the agreed three-collection architecture and a reviewable migration plan. The initial 2026-10-24 request was documentation-only. The user's subsequent instruction authorizes the privacy review, scoped local checkpoints to a clean working tree, and then beginning implementation. Start with the general-skills review/authoring boundary after that baseline. Remote publication, historical rewriting, credential changes, and unresolved external choices are not implied.

## Current state
- Architecture agreed: `agent-hands`, `project-workflows`, and `general-skills`; the first two are intended shareable submodules, and the third remains an ordinary configs folder initially.
- Both `log-kaizen` and `improve-agent-workflows` belong in `general-skills`, alongside `operate-lifeos`, `write-skills`, `track-changes`, and its proposed update companion.
- Service use combines supported read/write/comment operations by coherent domain; provider authorization is the main shared dependency, with further sharing justified by actual code.
- Project configuration lives inside its root-level `project-workflows/` submodule. Each adopting project gets a branch from adoption; the parent pins an exact child commit.
- The requested privacy review and scoped baseline checkpoints are complete. A clean working tree was verified before implementation; historical cache findings remain unresolved.
- The first implementation slice has relocated track-changes and write-skills, preserved existing client access through temporary file links, and added update-derived-skills with a recorded upstream baseline. The installer and source routing reflect the new owners; no upstream synchronization or new global install has happened.

## Project organization and principles
The conceptual document owns decisions, rationale, boundaries, proposed folder structure, service mapping, and open choices. This checklist owns work state. Public notes must contain only portable architecture and public-safe examples; actual account details, private endpoints, credential files, and personal context stay out.

Future work spans configs, two new package repositories, and selected consumers. The LifeOS boundary work belongs with its actual vault instructions when authorized; do not create executable helpers or credentials in the vault. Existing project-local instructions remain authoritative until deliberately migrated.

## To Do
### Gate and preservation baseline
- [ ] Inventory current command behavior and map every supported operation to its target use skill, including active/uncommitted capability changes.
- [ ] Map current code imports, shared helpers, executables, Python dependencies, configuration reads, credentials/caches, client symlinks, and known consumers.
- [ ] Record which restrictions are enforced by code versus skill guidance versus LifeOS policy; preserve each intended behavior without claiming uniform dry-run semantics.
- [ ] Establish a recovery/cutover plan that preserves existing working tools and ignored local configuration; do not disturb unrelated work.

### Resolve implementation choices
- [ ] Select repository ownership, remote URLs, licenses, default/project branch conventions, and visibility for project-specific changes.
- [ ] Finalize provider setup/authorization boundaries, code import layout, entrypoints, lockfile boundaries, and narrow shared helpers.
- [ ] Define supported platforms and onboarding prerequisites, including machines without uv, Python, or Bash.
- [ ] Define adjacent configuration schemas, per-skill examples, account selection, path resolution, and exact ignore rules.
- [ ] Decide the selected global/client installations separately from source ownership; keep project adoption independent of the general collection.

### Agent-hands extraction
- [ ] Establish the agent-hands repository/package structure and preserve appropriate attribution/history only after privacy review of material to be carried over.
- [ ] Extract Google authorization/setup support and Gmail, Drive, Docs, Sheets, Calendar, and Contacts skills with their existing supported capabilities.
- [ ] Extract Microsoft authorization/setup support and Outlook Mail, Calendar, Contacts, Files, Excel, and Planner skills with their existing supported capabilities.
- [ ] Extract Trello setup/authorization/use behavior, including neutral linking, checklists, and honest partial-failure handling.
- [ ] Extract Slack setup/authorization and separate messaging/Lists capabilities, preserving current access limits and known limitations.
- [ ] Extract Odoo setup/authorization/project-task capabilities with current bounds and rate handling.
- [ ] Extract GitHub setup/authorization and Issues, Projects, Pull Requests, and Discussions skills; do not add deferred Discussion writes.
- [ ] Generalize the Markdown-to-PDF pipeline with explicit inputs/themes/output; keep theme assets with the renderer and verify non-résumé use.
- [ ] Implement capability-selective uv/dependency provisioning and the setup-agent-hands entry procedure, without installing unrelated service stacks.
- [ ] Write the relevant MCP catalog with official sources, client/plugin distinctions, optional setup, capability overlap, and verification status.

### Project-workflows distribution
- [ ] Establish the project-workflows repository with the agreed project skills and no required general-skills or agent-hands dependency.
- [ ] Combine setup-project-docs and setup-local-skills into setup-project-workflows with templates, branch-from-adoption, configuration, parent routing, and clone instructions.
- [ ] Replace update-local-skills with update-project-workflows covering shared ancestry, semantic reconciliation, upstreamable changes, project-only divergence, and parent pointer updates.
- [ ] Add workflow.toml, .workflow.env.example, and ignore rules for .workflow.env inside the submodule; keep real project docs in the parent.
- [ ] Review mandatory Kaizen/authoring/general-skill references in project procedures and templates; make any adoption explicit without changing unrelated current policies.
- [ ] Pilot initial adoption and a subsequent upstream/local reconciliation in an explicitly selected project, preserving its existing documents and conventions.
- [ ] Verify the branch/pin procedure and that required child commits are reachable by collaborators before any parent reference is published.

### General skills and LifeOS ownership
- [ ] Implement update-derived-skills around a known upstream baseline and intentional adaptations; reconcile track-changes only after checking its actual upstream/plugin compatibility.
  - The maintenance procedure and structured record are implemented. The existing source note supplies a claimed baseline, not an independently verified comparison. Retrieve that baseline and check the actual upstream/plugin compatibility before completing the reconciliation portion of this item.
- [ ] Repoint remaining live references and existing client installations to the moved general-skills owners, verify fresh client discovery, then remove the temporary compatibility links.
- [ ] Replace lifeos-handoff with a thin operate-lifeos entry using ignored workspace pointers and vault-owned instructions.
- [ ] Retire the temporary skills/kaizen source route after remaining private references have been repointed. Existing vault-local Kaizen copies retain local authority until deliberately migrated.
- [ ] Move personal task-chain choices, account/resource mappings, snapshot/index destinations, combined-agenda orchestration, and résumé content/destination conventions into appropriate LifeOS procedures.
- [ ] Separate Google and Microsoft calendar implementations; settle any neutral shared renderer before removing current combined-agenda behavior.
- [ ] Verify the LifeOS adaptations use public neutral helpers without copying executable scripts, tokens, or private configuration into the vault.

### Installation, privacy, and cutover
- [ ] Wire the two collections as submodules in configs and update approved client skill links; do not create an unnecessary flattening layer.
- [ ] Add configs/agents/integrations.md for client selections and extras, referencing the portable MCP catalog instead of duplicating it.
- [ ] Update README, AGENTS routing, installer documentation, and affected consumers when the implementation actually changes their behavior.
- [ ] Perform the privacy pass over proposed files and relevant Git history before committing/publishing this work; inspect examples, identifiers, paths, caches, private defaults, and real ignore behavior.
- [ ] Assess any actual historical exposure and propose proportionate remediation separately; do not infer that history rewriting or a force push is required.
- [ ] Resolve the historical WebStorm-cache finding: establish whether any API-key-shaped values belong to accounts requiring action and review a separate history-cleanup proposal if desired. Do not test the keys, rewrite history, or push implicitly.
- [ ] Validate selected-service independence, setup idempotency, current guardrails, neutral outputs, and recovery paths with appropriate existing checks.
- [ ] Prepare scoped commits only after the review hold is satisfied; keep unrelated work separate and leave all pushes to the user.
- [ ] Repair callers before retiring obsolete CLI/skill entrypoints, with any temporary compatibility route explicitly bounded.
- [ ] Complete human QA and a durable-guidance/dependency review before requesting spike closure; keep the spike active until closure is authorized.

## Ready for Human QA
The first slice has file-level verification; a newly started Codex/Claude session should still discover and load `track-changes` and `write-skills` through its existing installation. No restart is required merely to continue this migration, and the new maintenance skill has not been installed globally.

As subsequent slices become ready, prepare concrete checks for:
- Fresh-machine bootstrap for each claimed platform, including missing uv/Python and a single selected service.
- Skill discovery and local-over-global selection in the actual agent clients.
- Project clone/adoption, branch selection, local divergence, and upstream reconciliation.
- General Markdown/PDF output and selected themes.
- Existing LifeOS operations after ownership moves, with live writes only for specifically authorized targets.

## Validation
The initial capture checks established paired frontmatter, relative links to existing owners, the exact TODO entry, agreed skill placement, and the distinction between decisions and open choices. That documentation-only checkpoint preserved pre-existing changes.

The first implementation slice checks YAML frontmatter with the available Ruby parser, TOML provenance, moved content, compatibility and installed-client link resolution, installer syntax under Bash/Zsh, relative documentation links, and whitespace. The standard Python skill validator could not run without PyYAML; do not report that validator as passed. No upstream synchronization, live service write, full installer run, or new test suite was performed.

## Done
- [x] Define Kaizen capture/review responsibilities and shared data/configuration contracts with both skills in general-skills. Independent procedures share current-concerns/incident Markdown records and literal env keys; legacy JSON discovery remains for existing consumers. Invalid selected configuration does not fall back to another destination.
- [x] Split the current Kaizen procedure into log-kaizen and improve-agent-workflows in general-skills; retain private routing and explicit approval for standing-rule changes. Verified YAML, private-file ignores, blank templates, existing destination access, owner-only local config permissions, installer syntax, and targeted client link resolution. No incident records or private paths were added to tracked files.
- [x] Retire log-skills-feedback and repair all live references and installer links. Removed the compatibility files, updated active README/global/authoring guidance, and removed only installer-owned Codex/Claude aliases. Historical spike references remain history; a separate short kaizen route preserves old private source links.
- [x] Correct the installer's directory-symlink replacement before further skill cutover. Temporary Bash/Zsh fixtures verify directory relinking without nesting, idempotency, dangling/fresh links, and preservation of real files/directories. No full installer run was needed.
- [x] Move track-changes and write-skills into general-skills while preserving local authority, source provenance, and client accessibility. Existing Codex/Claude links resolve through temporary file symlinks; the installer targets the new owners. Supporting authoring metadata was preserved byte-for-byte.
- [x] Define the minimum upstream baseline/adaptation record for track-changes and the proposed update-derived-skills procedure. Added `upstream.toml` with the existing source note's revision/date/release, explicit verification limits, and local preservation requirements. The companion procedure now exists; actual upstream reconciliation remains pending above.
- [x] Commit the reviewed spike and existing authorized changes in scoped checkpoints, then verify a clean working tree before implementation. No push or history rewrite was performed.
- [x] Obtain an explicit go-ahead for implementation and identify the first bounded migration slice. Planning approval is not implementation approval. The later 2026-10-24 request explicitly authorizes implementation after privacy review and a clean baseline; begin with general review/authoring skill relocation and derived-skill maintenance.
- [x] Perform the initial repository privacy review before checkpointing. Scanned 300 current files and 3,708 reachable historical blobs with no size skips; no current credential-pattern hits or matches to 16 current secrets were found. Local configuration remains ignored. Historical cache candidates remain a separate unresolved issue; no keys were tested or history rewritten.
- [x] Capture the agreed taxonomy, folder structure, skill breakdown, dependencies, configuration/distribution model, LifeOS boundary, open choices, and migration sequence in a conceptual spike. Saved 2026-10-24 under the initial documentation-only authorization; implementation was authorized afterward.
- [x] Create a separate operational checklist and add the spike to the root TODO index. Saved 2026-10-24 with only planning records in that initial scope.
- [x] Verify the documentation capture. Frontmatter, relative links, fenced blocks, agreed general-skill placement, index uniqueness, and whitespace checks passed. The TODO delta is exactly one added entry; pre-existing modified files were preserved. Additional edits appeared in the existing Excel spike files during capture and were left alone. No implementation, commit, or push was performed.

