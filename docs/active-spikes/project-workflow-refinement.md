# Project Workflow Refinement
Opened: 2026-10-12
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
Update the global seeds and directly affected operating guidance. Refresh the corresponding imported skills in the development repository that prompted this work after comparing them with the seeds. Other repositories' local skill copies are not automatically migrated. Preserve unrelated working-tree changes. No remote publication is part of this work.

Continues from: docs/archive/commit-work.md
Continues from: docs/archive/skill-authority.md
Continues from: docs/archive/skill-taxonomy.md
