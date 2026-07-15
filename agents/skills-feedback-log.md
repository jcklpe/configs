# Skills Feedback Log
Cross-project feedback about reusable agent skills and skill-like workflows.

Use this log for evidence-backed observations about skills, not ordinary project backlog. Capture friction here when the same lesson may apply across projects, global seed skills, local skill vendoring, or future skill authoring.

Do not automatically rewrite a skill from a single note. Log the observation, keep the evidence, and triage later.

## Open Feedback
### 2026-07-13 - Ready-For-Human-QA Items Should Move To Done, Not Just Tick
Skill or area: `run-project-spike` (spike QA/close-out workflow).

Observed behavior: when describing how to close a spike, an agent said an approved `Ready for Human QA` item should be checkmarked "in place" (tick the box). The user corrected that items with human approval should be *moved* out of the `Ready for Human QA` holding area into the `Done` section, not merely ticked.

Expected better behavior: the skill should state explicitly that `Ready for Human QA` is a holding area, and approved items leave it — they get moved into `Done` — so the QA list only ever shows still-pending review, never resolved items.

Context/evidence: Open Austin org repo, closing the `docs-taxonomy-refresh` spike on 2026-07-13. The `run-project-spike` "Archiving A Spike" and "Human QA" sections describe the QA list but do not spell out the move-to-Done transition, so an agent defaulted to ticking in place.

Candidate change: add a sentence to `run-project-spike` (Human QA and/or Archiving section) making the move-to-Done transition explicit; consider mirroring into any local copies.

Scope: global reusable.
