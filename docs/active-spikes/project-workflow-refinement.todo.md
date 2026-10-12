# Project Workflow Refinement Tasks
Spike: project-workflow-refinement

## Current State
The approved skill changes are implemented and validated as of 2026-10-12. All nine affected seeds and five imported copies pass the skill validator. The imported folders match their seeds; personal-path and supplied-resource checks pass. The development repository retains one unpushed initial commit and an unchanged consumer submodule. The remaining step is archive preparation and review of the closing message.

## To Do
- Validate the complete changes, prepare the archive with maintained-document pointers, and present the closing commit message for approval.

## Ready For Human QA
None yet.

## Done
- Refine commit scope, checkpoint timing, review holds, and privacy checks while preserving concurrency safeguards; reconcile directly affected repository instructions. — Implemented 2026-10-12 in `commit-work`, `AGENTS.md`, and the existing agent commit policy. Explicit-path selection remains; the text now distinguishes path isolation from same-file overlap and keeps related bookkeeping with its change. Skill validation and diff checks pass.
- Clarify spike maintenance, retained archives, closure navigation, and selection of shareable reasoning. — Implemented 2026-10-12 in `run-project-spike`. Archived pairs remain the default; closure dates, slugs, and maintained-document pointers make history navigable. Direct maintenance is distinguished from speculative discussion and the bounded closure check. Skill validation and diff checks pass.
- Make skill authoring, setup, and updates independent of personal installation paths; check dependencies while preserving intentional local divergence and the previously approved policy defaults. — Implemented 2026-10-12 in `write-skills`, `setup-local-skills`, `update-local-skills`, and `setup-project-docs`; checkpointed the previously approved policy terminology in the routing skills as part of this work. Removed the personal validator address and assumed seed-library location. Complete-folder validation and path/resource checks pass.
- Compare and refresh the affected imported skills in the development repository that prompted this work; validate both seeds and local copies. — Compared all five copies on 2026-10-12. Only `commit-work` and `run-project-spike` required refresh, with no local divergence; all five complete folders now match their seeds and pass validation. Folded the two updates into the requested single initial commit after verifying the remote was empty, retaining a recovery reference. The working tree is clean and the consumer submodule remains unchanged.
