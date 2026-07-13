---
name: log-skills-feedback
description: "Log evidence-backed feedback about reusable agent skills without immediately rewriting them. Use when an agent or user notices skill friction, a missing boundary, confusing trigger language, useful local divergence, a possible new skill, or a cross-project process improvement that should accrete in agents/skills-feedback-log.md."
---

# Log Skills Feedback
## Purpose
Use this skill to capture reusable skill/process feedback without turning every observation into an immediate skill edit. The log is for accreting evidence; later skill work can triage it.

Default log:

```text
~/configs/agents/skills-feedback-log.md
```

## What Belongs Here
Log feedback when it is cross-project or reusable:

- an agent hit friction using a skill
- a skill description did not trigger when it should have
- a skill boundary caused confusion
- a local project invented useful divergence that may belong upstream
- a repeated workflow looks like it may need a skill
- a skill worked unusually well and the pattern should be preserved

Do not use this log for ordinary project bugs, product work, UI nits, implementation tasks, or project-local backlog. Those belong in the current project's `docs/scratch/misc.md`, `docs/scratch/future-ideas.md`, `docs/pinned-issues.md`, active spikes, or decisions.

## Entry Shape
Append compact entries under `## Open Feedback`:

```md
### YYYY-MM-DD - Short Area
Skill or area: ...

Observed behavior: ...

Expected better behavior: ...

Context/evidence: ...

Candidate change: ...

Scope: global reusable | project-local | unclear
```

Keep entries evidence-backed. "This feels verbose" is not enough; "this description failed to trigger when the user asked X" is useful.

## Workflow
1. Confirm the issue is about reusable agent skill behavior, not normal project work.
2. Read `agents/skills-feedback-log.md` if it exists.
3. Avoid duplicate entries; update an existing open entry when it is clearly the same issue.
4. Append the new entry under `## Open Feedback`.
5. Do not edit the target skill unless the user explicitly asked for that work too.

## Triage Outcomes
When the user asks to review the log, route each item:

- update a global seed skill
- update a repo-local skill
- create a new skill
- move to project docs because it was project-local after all
- pin the issue if the right change is still unresolved
- discard if the feedback no longer applies

Remove or mark entries once they are handled. The log is an intake register, not permanent history.
