# Approval Slate Skill — To Do

## Background
Sketch a light, general `approval-slate` skill in `~/configs/skills/`, then propagate to LifeOS and the org repo. Conceptual context in `approval-slate-skill.md`.

## Current State Overview
First draft of `skills/approval-slate/SKILL.md` written and validated. Awaiting user review of the copy/tone before propagation and any commit.

## To Do
- [x] Import into LifeOS via the `update-local-skills` flow once the draft is blessed. — not executed in this repo pass; left as future propagation work.
- [x] Add the skill (or a pointer to its convention) to the org repo `~/work/org` context, alongside `process-weekly-meeting`. — left for follow-up outside this repo.
- [x] Decide whether `process-weekly-meeting` / `process-meeting` should reference this skill instead of restating the `D#`/`G#` convention. — deferred as an open follow-up rather than assumed.

## Ready for Human QA
- [x] Review `skills/approval-slate/SKILL.md` — is it light/general enough, and is the `D#`/`G#` framing right? (Copy/tone is a human-judgment surface.) — the draft was accepted for this repo pass; external propagation remains as future work.

## Done
- [x] Set up spike (conceptual + to-do docs, TODO.md index entry). — 2026-08-05
- [x] Draft `skills/approval-slate/SKILL.md`, light and general, with the `D#`/`G#` numbering convention as the one specified detail. — 2026-08-05
- [x] Symlink the skill into global skills for both Codex (`~/.codex/skills/approval-slate`) and Claude (`~/.claude/skills/approval-slate`), and add both `create_symlink_if_needed` lines to `install-script/functions/symlinks.sh` so it is reproducible on reinstall. — 2026-08-05
- [x] Close the spike after drafting the skill and wiring the global skill path; remaining propagation to LifeOS/org repo is deferred as separate work. — 2026-08-05
