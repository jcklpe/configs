---
attention: live
---
# LifeOS Planner Labels and Comments Tasks
## Done
- Read repo instructions, local LifeOS skills, run-project-spike and commit-work; confirmed canonical tools and preserved the unrelated working-tree edit.
- Checked official task update and group conversation APIs. Configured scopes initially appeared to block comments; unchanged CLI auth metadata confirmed existing effective group read/write permission, so no OAuth expansion was needed.
- Implemented existing-label listing and dry-run-first label/unlabel with unique name resolution, preservation, ETag, attempt audit and readback.
- Implemented task-scoped comment list/add with existing-scope checks, complete bounded reads, text deduplication, private recovery journals, first-thread linkage and preserved-field verification.
- Updated CLI help, README, local M365 skill and policy 0008. Searched the vault skills for affected Planner assumptions; no matches needed updates.
- Offline Planner, comment, shell and renderer regressions pass. Syntax checks and fixture exercise cover bash and zsh.
- Live label listing and label command verified: target already had its label, so preview and execute were no-ops. Live label PATCH remains unverified.
- Live comment list, exact preview, first-thread creation, read-only recovery after initial 404, conditional linkage, and independent single-post/task-field verification passed. No duplicate POST occurred during recovery. Private execution evidence stays outside configs.
- Refreshed the canonical snapshot, inspected the final scoped diff and prepared the implementation checkpoint with `Spike: lifeos-planner-labels-comments`.
## Ready for Human QA
- Live label PATCH validation awaits a future authorized actual label change; the already-correct target was not toggled for testing.
- Existing-thread reply has offline coverage but remains unverified live; do not add a second real comment just for QA.
- Inspect the linked comment in ordinary Planner use; terminal/API verification is complete, with no browser fallback.
## Blocked
None. Spike closure and archival remain pending explicit authorization; implementation checkpoints are authorized.
