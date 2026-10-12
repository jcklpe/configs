# Project Workflow Refinement Tasks
Status: active. Closing message wording approved 2026-10-12; readiness to close remains under discussion.
Spike: project-workflow-refinement

## Current State
The approved skill changes are implemented as of 2026-10-12. All nine affected seeds and five imported copies passed structural validation, and the imported folders match their seeds. These checks do not establish how a fresh agent will interpret the workflows. A subsequent readiness review found that the existing-copy guard in `setup-local-skills` followed its copy step; that ordering is now corrected. The development repository retains one unpushed initial commit and an unchanged consumer submodule. Closing-message wording is approved, but closure itself is not; the pair remains active. The [conceptual document](project-workflow-refinement.md) links the maintained guidance.

## To Do
None.

## Ready For Human QA
- Decide whether the spike is ready to close. — Closing-message wording approved 2026-10-12; closure remains unapproved while readiness and the archive tradeoff are discussed.

## Done
- Validate the complete changes, prepare the archive with maintained-document pointers, and present the closing commit message for approval. — Structural validation and archive preparation completed on 2026-10-12. The user approved the message wording but questioned readiness, so the documents returned to active work. No archival commit was made.
- Correct the existing-copy guard ordering in `setup-local-skills`. — Found during the 2026-10-12 readiness review; the workflow now routes existing skills to comparison/update before any copy can occur. Fresh-agent behavioral validation has not been performed.
- Refine commit scope, checkpoint timing, review holds, and privacy checks while preserving concurrency safeguards; reconcile directly affected repository instructions. — Implemented 2026-10-12 in `commit-work`, `AGENTS.md`, and the existing agent commit policy. Explicit-path selection remains; the text now distinguishes path isolation from same-file overlap and keeps related bookkeeping with its change. Skill validation and diff checks pass.
- Clarify spike maintenance, retained archives, closure navigation, and selection of shareable reasoning. — Implemented 2026-10-12 in `run-project-spike`. Archived pairs remain the default; closure dates, slugs, and maintained-document pointers make history navigable. Direct maintenance is distinguished from speculative discussion and the bounded closure check. Skill validation and diff checks pass.
- Make skill authoring, setup, and updates independent of personal installation paths; check dependencies while preserving intentional local divergence and the previously approved policy defaults. — Implemented 2026-10-12 in `write-skills`, `setup-local-skills`, `update-local-skills`, and `setup-project-docs`; checkpointed the previously approved policy terminology in the routing skills as part of this work. Removed the personal validator address and assumed seed-library location. Complete-folder validation and path/resource checks pass.
- Compare and refresh the affected imported skills in the development repository that prompted this work; validate both seeds and local copies. — Compared all five copies on 2026-10-12. Only `commit-work` and `run-project-spike` required refresh, with no local divergence; all five complete folders now match their seeds and pass validation. Folded the two updates into the requested single initial commit after verifying the remote was empty, retaining a recovery reference. The working tree is clean and the consumer submodule remains unchanged.
