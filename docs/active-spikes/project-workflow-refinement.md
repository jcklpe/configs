---
attention: live
---
# Project Workflow Refinement
Opened: 2026-10-12
Status: active. Cross-repository rollout, archive markers, and the five further workflow refinements plus diagnostic correction are approved and implemented as of 2026-10-12. Closure remains unapproved.
Spike: project-workflow-refinement

## Purpose
Refine the reusable project workflow skills after reviewing how spikes, granular commits, and copied skills work together. Substantial project work continues to use conceptual/to-do pairs. This is a bounded update to the existing process, not a replacement documentation system.

## Agreed Approach
Routine in-scope checkpoints remain autonomous where the repository permits them. An explicit request to review before committing temporarily overrides that default. The closing spike message still receives human review.

Preserve fairly granular commits for completed changes, distinct experiments, consequential corrections, and useful recovery points. Prompt checkpoints help keep concurrent spikes traceable and reduce the window for unrelated changes to accumulate. Explicit path selection prevents unrelated staged paths from entering a commit; it does not isolate two agents editing the same file. Inspect full selected diffs and do not silently claim or overwrite another workstream's changes.

Keep implementation, its task record, and its own index update together when they describe one change. Separate coordination-file commits remain appropriate when those files genuinely combine independently authorized workstreams. A turn boundary alone does not require a commit, and related bookkeeping is not a second change merely because it is in another file.

## History and Current Guidance
Keep archived spike pairs by default. They make historical reasoning discoverable through ordinary file searches and provide a subject-level entry point into the finer commit history. Git preserves earlier versions; it does not make the final archived documents redundant for navigation.

Integration into maintained project guidance is already a closure requirement. Retain it, including substantial reasoning and qualifications, rather than treating integration as a new process or a compression exercise. At closure, add the date, stable spike slug, and pointers to the maintained guidance or successor work. Preserve the historical body; later navigation repairs do not turn it into a current-state document.

Repair direct links and instructions when an actual change lands. Keep developing alternatives in the spike rather than repeatedly rewriting durable guidance. At closure, check the live guidance affected by the spike; this does not authorize a repository-wide audit or writes to other systems.

## Privacy and Portability
Select material for the repository's audience before writing it. Preserve project reasoning without copying unnecessary or unauthorized private conversation, source material, personal paths, or surrounding workspace details. Distinguish user-adopted positions from agent proposals. Review the selected diff and commit message as a second check; later history rewriting is not the primary safeguard.

Reusable skills use repository-relative references and configured or discovered dependency locations. Complete-folder copying preserves resources but does not establish that dependencies are available. Check portability during authoring, initial copying, and updating; preserve intentional local divergence and avoid silent adaptations or blanket overwrites.

## Boundaries
Update the global seeds and directly affected operating guidance. The initial scope refreshed corresponding imported skills in the development repository that prompted this work. On 2026-10-12 the user expanded the scope to roll the approved improvements into other existing local copies before closure. Compare each copy and preserve its project authority, privacy boundaries, commit policy, and deliberate layout differences. Do not install the library into repositories that do not already carry these workflows. Preserve unrelated working-tree changes. No remote publication is part of this work.

## Attention Markers and Archive Tradeoff
Use explicit `attention: live` for active spike pairs and `attention: historical` at closure, respecting equivalent local conventions. The field describes maintenance and authority, not task completion or agreement with every proposal. A visible historical notice and pointers to maintained guidance reinforce the marker when an archived file is retrieved on its own. The initial rollout adapted an existing local practice without requiring a universal metadata system or automatically retagging old archives; the user subsequently requested the bounded backfill recorded below.

Retaining the full pair remains the working default, not a demonstrated optimum. Searchable files provide a useful route into Git history, but a shorter historical entry could also provide that route. Keeping the pair additionally preserves the task-to-outcome relationship and surrounding reasoning without asking a later agent to reconstruct them across commits. The tradeoff is more historical material that may be mistaken for current guidance; markers and navigation reduce that risk without eliminating it. Revisit the default if actual retrieval shows recurrent confusion or an archive that materially obstructs useful work.

## Maintained Guidance
- [Commit work](../../skills/commit-work/SKILL.md) and the [repository commit policy](../decisions/0003-agent-commit-policy.md) own checkpoint scope, concurrency, review holds, and the pre-commit audience check.
- [Run project spike](../../skills/run-project-spike/SKILL.md) owns active reasoning, bounded maintenance, retained archives, and closing-message review.
- [Write skills](../../skills/write-skills/SKILL.md), [setup local skills](../../skills/setup-local-skills/SKILL.md), and [update local skills](../../skills/update-local-skills/SKILL.md) own path portability and dependency checks.
- [Setup project docs](../../skills/setup-project-docs/SKILL.md) owns the reusable scaffold and current-policy defaults; [triage project misc](../../skills/triage-project-misc/SKILL.md), [pin issue](../../skills/pin-issue/SKILL.md), and [log future idea](../../skills/log-future-idea/SKILL.md) use those defaults.

## Rollout — 2026-10-12
The global sources live in this repository's `skills/`; imported copies are independently maintained project authority. This rollout compared existing copies before updating them. It did not install skills into repositories without matching workflows, rename governance folders, retag old archives, or publish changes.

| Target | Updated copies | Local differences retained |
| --- | --- | --- |
| ResearchOps development repository | `run-project-spike` and `triage-project-misc`; its other three imported skills already matched the updated seeds | Current policies and maintainer/consumer separation; consumer submodule unchanged |
| Website repository | `commit-work`, `run-project-spike`, `triage-project-misc`, `pin-issue`, `log-future-idea`, `setup-project-docs`, `setup-local-skills`, `update-local-skills` | Existing `docs/decisions/` location; repository instructions continue to own implementation and human visual QA |
| Organization tooling repository | `commit-work`, `run-project-spike`, `triage-project-misc`, `pin-issue`, `log-future-idea`, `update-local-skills` | Organization-specific purpose, authority, governance protection, public-data boundaries, notifications, and external-write approvals |
| Shared team project | `commit-work`, `run-project-spike`, `triage-project-misc`, `pin-issue`, `write-skills` | Existing `docs/decisions/` location, team worktree safeguards, and distinction between human issue tracking and agent spike details |
| Private vault | Local spike, pinning, future-idea, and misc-triage workflows merged selectively | Daily vault-wide commits, private-context rules, native metadata, focus-thread routing, and local close-out |

The website and shared-team copies matched older seed versions before this refresh. The organization and vault copies had substantial local specialization, so those were merged rather than replaced. One stale documentation-tree entry and a live setup instruction that assumed the seed maintainer's personal checkout were also corrected in the organization repository. Dependency review found that optional future-idea and skill-feedback helpers were not vendored in every target; their callers now describe an explicit local fallback instead of assuming a global installation. No private source content was imported into this record.

Validation covered 33 standard skill folders, four vault-native skills under their own metadata conventions, referenced resources, relative Markdown links, personal-path checks, and changed-file whitespace. This establishes structural consistency, not fresh-agent behavioral success. The new archive markers have not yet been evaluated in real retrieval after rollout.

## Archive Backfill — 2026-10-12
The user requested bulk historical markers for existing archives. The inventory covered Markdown recursively under `docs/archive/` in the six repositories already in rollout scope, including supporting development records and retired policies in those folders. It did not include unrelated personal archives or arbitrary folders named Archive.

| Repository | Newly marked historical | Already historical |
| --- | ---: | ---: |
| Global skill source | 45 | 0 |
| Private vault | 25 | 23 |
| Website | 90 | 0 |
| Organization tooling | 19 | 0 |
| ResearchOps development | 0 | 0 |
| Shared team project | 0 | 0 |

All 202 documents now have `attention: historical`; 179 required an edit. None had a conflicting attention value. Byte comparisons against pre-edit snapshots verified that bodies, existing frontmatter values, line endings, and encoding markers were preserved. No review or closure dates were invented, and no historical task lists or implementation descriptions were rewritten. The two zero-count repositories currently have no Markdown in `docs/archive/`.

This backfill marks authority; it does not certify historical claims, repair all archive navigation, or establish that current knowledge was fully integrated at each original closure. No present-state routing changed in the private vault, and its existing daily checkpoint already satisfies that day's commit cadence; its metadata edits may remain for the next vault-wide checkpoint rather than sweeping concurrent work into this task.

## Further Review — Approved Corrections
Review of the current spike and commit workflows found shared instruction conflicts rather than a missed copy rollout. All four imported `commit-work` copies match the seed. The ResearchOps spike copy also matches; the website and shared-team copies retain governance-directory adaptations, while organization and private-vault copies retain more extensive local authority and workflow differences. Structural validation did not catch the following semantic problems. The user approved all five corrections and the mechanical error fix on 2026-10-12; the findings below describe the prior guidance and the adopted remedy.

1. **Closure readiness and message approval are conflated.** The previous general spike procedure marked documents historical, moves them, and updates the index before asking for closing-message approval. In this spike, approval of wording did not establish readiness to close. Adopted correction: prepare the closure summary and affected-document check while the pair remains active, and establish that closure itself is authorized before applying the archive transition. Wording-only approval is not closure. One explicit closure decision can cover both readiness and the message; do not add repeated approval gates. Preserve the private vault's existing requirement for approval before archival moves.
2. **The spike requirement contradicts the patch route.** The previous spike purpose only exempted throwaway actions, while `commit-work` provides a meaningful, self-contained `Patch:` workflow. Adopted correction: keep substantial or evolving work in spikes and allow a bounded one-off patch without creating a conceptual/to-do pair. Its commit body holds its purpose and reasoning. This reflects the user's stated occasional-patch exception; it is not a new intermediate conversation-document format.
3. **Unrelated dirty paths trigger contradictory instructions.** The previous `commit-work` said separate-path work needed no coordination ritual, then told agents to stop and ask when they encounter unrelated changes. Adopted correction: leave those paths alone and continue within the authorized scope; ask when shared-file overlap, dependencies, or uncertain ownership prevent a safe checkpoint. Preserve stronger local worktree requirements. Update the corresponding repository commit policy and rationalization examples if this change is adopted.
4. **Rewrite verification assumes only commit messages change.** The previous skill and source repository policy required an unchanged final tree for every authorized rewrite and assume a particular rewrite tool's backup behavior. That does not cover the user's approved fresh-initial-commit workflow, which incorporated reviewed content. Adopted correction: create an explicit recovery reference before a rewrite, check for competing work first, and verify according to the authorized operation: identical final contents for a message-only change or squash preserving the final state, and exactly the approved content changes when those are part of the request. Authorization and publication boundaries remain intact.
5. **The closure check needs a concrete test for misplaced current authority.** Integrating durable knowledge is already required; this is a way to verify it, not a new integration stage. The website's maintained agent instructions described an archived live-halftone note as the home of current verification limits. Adopted correction: during the existing bounded close-out check, distinguish historical evidence links from instructions that delegate current authority to an archive. Verify and place maintained claims in their current owner, retaining archive links for provenance. Do not bulk promote historical prose into current guidance or rewrite archive bodies.

The mechanical error in `commit-work` is also corrected: the explanation below the failure-mode table now associates bounded retries with index-lock errors and `check-ignore` with the ambiguous unknown-path errors.

Implemented the approved corrections in both global skills, all four corresponding imported pairs, and the private vault's specialized spike skill. Reconciled this repository's agent instructions and commit policy. Updated the website's closure instructions and directed verification guidance to a maintained design-system section, retaining archive links as dated evidence and the existing active spike as the QA owner. No historical body was rewritten and no old experiment was reopened. The shared-team project's stronger dirty-worktree rule, organization governance, existing documentation locations, and private-vault daily cadence remain intact.

Validation: all ten standard skill folders pass the available skill validator; the vault-native skill passes its own frontmatter and reference checks. Relative links resolve, imported commit skills match the seed, and the website/shared-team spike copies differ only by their existing documentation convention. Checked the instructions against wording-only closure approval, explicit closure approval, small patch versus substantial work, separate-file versus shared-file edits, and message-only versus content-changing rewrites. This was a manual scenario review, not an independent fresh-agent execution test. Real archive retrieval remains unevaluated. This spike stays active; approval of these refinements does not authorize its closure.

Continues from: docs/archive/commit-work.md
Continues from: docs/archive/skill-authority.md
Continues from: docs/archive/skill-taxonomy.md
