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
- Microsoft authorization/setup support is extracted, with independent locked MSAL, optional Graph PowerShell, literal config, fixed service destinations, private token staging, and bounded paging. Legacy account paths and SDK-context behavior are retained; service extraction is next.
- Google Calendar is extracted with account-based provider support, explicit-output agendas, preserved event gates, and no Microsoft/contact dependency. Legacy combined agendas, nickname selection, credential slots, and window defaults remain compatible. All Google capabilities are extracted; private composition/cutover is still pending.
- Gmail is extracted with provider-only support, explicit-output exports, a private audit route, and retained label/filter gates. Failed deletion verification no longer reports confirmed success. Legacy queries, account paths, and aggregate routing remain compatible; Calendar has subsequently been extracted.
- Google Drive is extracted with explicit-output bounded indexes, staged downloads, retained import gates, and independent provider-only use. Legacy sync keeps private routing; exclusion guidance now accurately describes child-listing scope rather than promising a privacy filter. Calendar is also extracted; legacy composition remains.
- Google Sheets value reads are extracted with independent scope selection, explicit ranges, a local uv environment, and a small provider-shared table formatter. Legacy Drive sheet reads remain compatible; Drive and Gmail are now also extracted; Calendar is now extracted.
- Google Contacts lookup is extracted independently of Calendar and private nickname maps. Existing caller selection rules remain in the legacy workflow; the portable skill returns candidates only, with incomplete-pagination checks and optional account-based Contacts scopes.
- Google Docs and shared Google authorization/setup are extracted with independent uv manifests, literal config, owner-only token staging, and a whole-tab concurrency check. Legacy Google account paths remain in the compatibility caller. Remaining Google capabilities and calendar composition are still pending.
- GitHub now has four independent domain entrypoints with gh-backed provider support, optional aliases, explicit-output exports, and per-domain uv rendering. Existing issue-create/board-move gates remain; no Discussion writes were added. Legacy aggregate routing retains private config. Example identities and repository mappings are synthetic.
- Trello is extracted with independent provider/setup/use skills and its existing direct-write model. The portable exporter requires an explicit file; snapshot failures preserve previous output. Legacy routes retain private defaults. Neutral linking reports partial outcomes and avoids recreating a successor during recovery.
- Slack messaging and Lists now have independent Python entrypoints sharing only provider support, tailored ignored configuration, setup guidance, and per-capability uv locks. Existing commands retain their old private configuration and snapshot routing. Existing offline checks and isolated capability checks passed; no live write or credential migration occurred.
- Agent Hands now has an independent local repository with Odoo provider support, bounded operations, and setup skills. The old command delegates to extracted code without migrating private config. Offline checks passed in isolation; no live service operation or remote publication occurred.
- Public GitHub destinations and AGPL-3.0-only are selected. Project-workflows is an independent local submodule with a configs branch, combined setup/update skills, templates, and private-config ignores. Neither new remote repository has been created or published.
- Architecture agreed: `agent-hands`, `project-workflows`, and `general-skills`; the first two are intended shareable submodules, and the third remains an ordinary configs folder initially.
- Both `log-kaizen` and `improve-agent-workflows` belong in `general-skills`, alongside `operate-lifeos`, `write-skills`, `track-changes`, and its proposed update companion.
- Service use combines supported read/write/comment operations by coherent domain; provider authorization is the main shared dependency, with further sharing justified by actual code.
- Project configuration lives inside its root-level `project-workflows/` submodule. Each adopting project gets a branch from adoption; the parent pins an exact child commit.
- The requested privacy review and scoped baseline checkpoints are complete. A clean working tree was verified before implementation; historical cache findings remain unresolved.
- The first implementation slice has relocated track-changes and write-skills, preserved existing client access through temporary file links, and added update-derived-skills with a recorded upstream baseline. The installer and source routing reflect the new owners; no upstream synchronization or new global install has happened.
- Subsequent slices split and installed the two Kaizen replacements, retired the feedback alias, and replaced the installed handoff entry with operate-lifeos. Actual private pointers remain ignored; the vault owns its reporting format. All six general skills now exist; upstream reconciliation and remaining bridge cleanup are still pending.

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
- [x] Select public `jcklpe/agent-hands` and `jcklpe/project-workflows` repositories with AGPL-3.0-only, shared `main`, and `codex/project-<slug>` branches. Keep sensitive project variants on separately accessible private remotes; remote creation/publication has not occurred.
- [ ] Finalize provider setup/authorization boundaries, code import layout, entrypoints, lockfile boundaries, and narrow shared helpers.
- [ ] Define supported platforms and onboarding prerequisites, including machines without uv, Python, or Bash.
- [ ] Define adjacent configuration schemas, per-skill examples, account selection, path resolution, and exact ignore rules.
- [ ] Decide the selected global/client installations separately from source ownership; keep project adoption independent of the general collection.

### Agent-hands extraction
- [x] Establish the agent-hands repository/package structure and preserve appropriate attribution/history only after privacy review of material to be carried over.
- [x] Extract Google authorization/setup support and Gmail, Drive, Docs, Sheets, Calendar, and Contacts skills with their existing supported capabilities. Legacy composition and final caller cutover remain separate tasks.
- [ ] Extract Microsoft authorization/setup support and Outlook Mail, Calendar, Contacts, Files, Excel, and Planner skills with their existing supported capabilities.
- [x] Extract Trello setup/authorization/use behavior, including neutral linking, checklists, and honest partial-failure handling.
- [x] Extract Slack setup/authorization and separate messaging/Lists capabilities, preserving current access limits and known limitations.
- [x] Extract Odoo setup/authorization/project-task capabilities with current bounds and rate handling.
- [x] Extract GitHub setup/authorization and Issues, Projects, Pull Requests, and Discussions skills; do not add deferred Discussion writes.
- [ ] Generalize the Markdown-to-PDF pipeline with explicit inputs/themes/output; keep theme assets with the renderer and verify non-résumé use.
- [x] Implement capability-selective uv provisioning for the extracted Slack services; continue applying that pattern as other Python services are extracted. The setup entry routes Odoo without Python and Slack through independent standard-library Python manifests/locks; no all-provider environment is required.
- [ ] Write the relevant MCP catalog with official sources, client/plugin distinctions, optional setup, capability overlap, and verification status.

### Project-workflows distribution
- [x] Establish the project-workflows repository with the agreed project skills and no required general-skills or agent-hands dependency.
- [x] Combine setup-project-docs and setup-local-skills into setup-project-workflows with templates, branch-from-adoption, configuration, parent routing, and clone instructions.
- [x] Replace update-local-skills with update-project-workflows covering shared ancestry, semantic reconciliation, upstreamable changes, project-only divergence, and parent pointer updates.
- [x] Add workflow.toml, .workflow.env.example, and ignore rules for .workflow.env inside the submodule; keep real project docs in the parent.
- [x] Review mandatory Kaizen/authoring/general-skill references in project procedures and templates; make any adoption explicit without changing unrelated current policies.
- [ ] Complete a subsequent real upstream/local reconciliation in the configs pilot. Initial local adoption is implemented; the isolated fixture verified ancestry/merge behavior, not a published upstream update.
- [ ] Verify the branch/pin procedure and that required child commits are reachable by collaborators before any parent reference is published.

### General skills and LifeOS ownership
- [ ] Implement update-derived-skills around a known upstream baseline and intentional adaptations; reconcile track-changes only after checking its actual upstream/plugin compatibility.
  - The maintenance procedure and structured record are implemented. The existing source note supplies a claimed baseline, not an independently verified comparison. Retrieve that baseline and check the actual upstream/plugin compatibility before completing the reconciliation portion of this item.
- [ ] Repoint remaining live references and existing client installations to the moved general-skills owners, verify fresh client discovery, then remove the temporary compatibility links.
- [ ] Retire the temporary lifeos-handoff source route after remaining source consumers have migrated to operate-lifeos.
- [ ] Retire the temporary skills/kaizen source route after remaining private references have been repointed. Existing vault-local Kaizen copies retain local authority until deliberately migrated.
- [ ] Move personal task-chain choices, account/resource mappings, snapshot/index destinations, combined-agenda orchestration, and résumé content/destination conventions into appropriate LifeOS procedures.
- [ ] Separate Google and Microsoft calendar implementations; settle any neutral shared renderer before removing current combined-agenda behavior.
- [ ] Verify the LifeOS adaptations use public neutral helpers without copying executable scripts, tokens, or private configuration into the vault.

### Installation, privacy, and cutover
- [ ] Finish selected global/client cutover and retire temporary source bridges after consumers migrate. Both collections are registered locally as submodules; workflow links are updated. Existing Odoo callers retain their legacy configuration route, while other service extraction remains.
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
- [x] Extract shared Microsoft authorization/request support without migrating account configuration. Verify literal paths/aliases, preserved scope mapping, endpoint refusal, page/failure cleanup, owner-only token staging, locked MSAL installation/import, and PowerShell account matching using a synthetic module. Legacy service fixtures pass; no real account operation occurred.
- [x] Extract Google Calendar/provider scopes and keep legacy credential/composition routes. Preserve preview, writable-calendar, notification, timezone, recurrence, and settings-readback behavior; correct explicit empty attendee replacement. Retained fixtures plus paging/failure/gate/isolation checks pass offline, including the legacy combined agenda. No credentials, invitations, or live events were changed.
- [x] Extract Gmail with its own uv environment, bounded explicit exports, provider-only dependencies, and adjacent ignored audit output. Preserve legacy mail routing and mixed-provider checks. Synthetic checks cover label/filter gates, retry/render behavior, failed export preservation, uncertain deletion readback, private audit creation, cleanup, and isolated use. No actual mail or credentials were accessed.
- [x] Extract Google Drive operations and preserve legacy sync routing. Fix download data loss and index false-success paths; check failed-read preservation, path safety, import opt-in/preview, cleanup, and standalone use with synthetic data. No real index, file, credential, or remote account was changed.
- [x] Extract Google Sheets range reading and shared table formatting. Preserve default/explicit range behavior and legacy rendering, clean temporary data on failure, and check isolated use with sanitized fixtures. No live sheet data or write was used.
- [x] Extract read-only Google Contacts with shared authorization, a local uv environment, and retained legacy lookup routing. Check saved/other-contact precedence, deduplication, incomplete-read failure, scope selection, and standalone use. No private nickname mappings or actual contact data entered the package.
- [x] Extract Google Docs with provider authorization/setup, retained command compatibility, and synthetic examples. Check preview gates, exact formatting/comment behavior, whole-tab revision conflicts, token permissions/failure preservation, literal configuration, and legacy caller compatibility offline. No real credentials or remote operations were used.
- [x] Extract the GitHub domain skills and narrow shared issue/PR response helpers. Preserve legacy routing and the two dry-run/execute gates; permit literal owner/repo use without a private alias file. Verify synthetic render/request fixtures, literal arguments, read-failure preservation, reply-truncation notices, and domain isolation. No live GitHub operation, account change, push, or real config migration occurred.
- [x] Extract Trello operations and preserve legacy callers. Fix confirmed false-success export paths, propagate pipeline failures, canonicalize link references, and provide safe partial-link recovery wording. Retained renderer/checklist fixtures, failure-path checks, provider configuration checks, and isolated use pass offline. No credentials or live service writes were used.
- [x] Extract Slack messaging/Lists/provider/setup skills, preserve existing request/identity/discussion checks, and retain legacy CLI routing. Literal env parsing, fixed API destination, safe account aliases, and adjacent credential ignores are checked. Documentation distinguishes response-based message confirmation from exact List-comment verification; no private account observations were carried into package docs.
- [x] Extract the first neutral service capability and register Agent Hands locally. Odoo preserves its operation bounds and legacy caller configuration, while the standalone route uses literal env parsing and adjacent ignored files. Retained request fixtures plus configuration/isolation checks pass; no live account/write or real credentials were carried into the new history.
- [x] Prepare and adopt the project-workflows collection locally. Preserve six procedure bodies/assets, add two adoption/update procedures and templates, retain source notices, configure the project branch and parent pin, and repair global routing. Verified frontmatter, TOML, links, shell syntax, privacy/ignore behavior, and an isolated branch/merge/recursive-clone fixture. Real remote availability and fresh client discovery remain unverified.
- [x] Replace lifeos-handoff with a thin operate-lifeos entry using ignored workspace pointers and vault-owned instructions. Preserved the four prior handoff/attribution sections in the private owner, added private routing, verified YAML and links, and installed the replacement in Codex/Claude. Real pointers are ignored and owner-readable; the public example contains no private location. Unrelated vault edits remain untouched.
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

