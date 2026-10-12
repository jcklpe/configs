---
attention: live
---
# Project Workflow Refinement
Opened: 2026-10-12
Status: active. Cross-repository rollout and explicit attention markers added to scope on 2026-10-12; closure remains unapproved.
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
Use explicit `attention: live` for active spike pairs and `attention: historical` at closure, respecting equivalent local conventions. The field describes maintenance and authority, not task completion or agreement with every proposal. A visible historical notice and pointers to maintained guidance reinforce the marker when an archived file is retrieved on its own. This adapts an existing local practice without requiring a universal metadata system or retroactively retagging all archives.

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

No successor spike is required for this bounded update. Existing repository-specific vocabulary and local skill differences retain their own authority during rollout.

Continues from: docs/archive/commit-work.md
Continues from: docs/archive/skill-authority.md
Continues from: docs/archive/skill-taxonomy.md
