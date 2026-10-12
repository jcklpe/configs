# Project Workflow Refinement Tasks
Spike: project-workflow-refinement

## Current State
The approach was approved on 2026-10-12. Commit and spike guidance is implemented and validated. Portability changes and the corresponding imported copies are being checked before their checkpoint. Existing uncommitted policy-default and setup improvements belong to this work; unrelated terminal configuration changes do not.

## To Do
- Make skill authoring, setup, and updates independent of personal installation paths; check dependencies while preserving intentional local divergence and the previously approved policy defaults.
- Compare and refresh the affected imported skills in the development repository that prompted this work; validate both seeds and local copies.
- Validate the complete changes, prepare the archive with maintained-document pointers, and present the closing commit message for approval.

## Ready For Human QA
None yet.

## Done
- Refine commit scope, checkpoint timing, review holds, and privacy checks while preserving concurrency safeguards; reconcile directly affected repository instructions. — Implemented 2026-10-12 in `commit-work`, `AGENTS.md`, and the existing agent commit policy. Explicit-path selection remains; the text now distinguishes path isolation from same-file overlap and keeps related bookkeeping with its change. Skill validation and diff checks pass.
- Clarify spike maintenance, retained archives, closure navigation, and selection of shareable reasoning. — Implemented 2026-10-12 in `run-project-spike`. Archived pairs remain the default; closure dates, slugs, and maintained-document pointers make history navigable. Direct maintenance is distinguished from speculative discussion and the bounded closure check. Skill validation and diff checks pass.
