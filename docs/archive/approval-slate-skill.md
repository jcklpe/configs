# Approval Slate Skill — Conceptual

Status: archived 2026-08-05. The spike drafted a general `approval-slate` skill and closed after the skill text and global symlink wiring were in place.

> Rename note (2026-08-07): the skill was renamed `approval-slate` → `draft-approval-slate` (a verb-first imperative). Live path is now `~/configs/skills/draft-approval-slate/`, symlinked to `~/.codex/skills/draft-approval-slate` and `~/.claude/skills/draft-approval-slate`. The historical prose below predates the rename and is left as-is.

Companion to-do: `docs/archive/approval-slate-skill.todo.md`.

## Purpose
Extract the "approval slate" pattern into a reusable, lightweight skill: an agent gathers a batch of proposed external or hard-to-reverse changes, presents them as a numbered slate with final copy, and executes only what the user approves.

## Origin
Emerged 2026-08-05 while restructuring Open Austin's Infrastructure GitHub issues. The pattern was already used informally by `process-weekly-meeting` (org repo) and `process-meeting` (LifeOS), which number document changes `D#` and GitHub changes `G#`. The user asked to generalize it so it can be reached for any batch of reviewable changes, not just meeting reconciliation.

## Philosophy
- **Light, not ceremony.** A slate is however much structure makes a batch reviewable — no rigid template.
- **Don't prematurely crystallize.** Resist over-specifying; the pattern should stay general.
- **Composes with, does not replace, per-repo write-safety rules.** Dry-run defaults, "plan before bulk", and approval-required action lists still govern; the slate is the presentation/gating layer on top.

## The one convention worth specifying
Number proposed changes by **domain prefix** so a reference is unambiguous and easy to say aloud:
- `G#` — GitHub changes
- `D#` — document / vault / config changes
- other prefixes as a slate spans systems (e.g. `C#` calendar, `M#` mail)

"Approve G2, hold G5" is unambiguous; bare `1, 2, 3` reads as a count ("approve 2" = approve two things?), and decorative glyphs (①/③) are hard to read and hard to reference.

## Home and propagation
- **Author in `~/configs/skills/approval-slate/`** as a global seed skill (broad, cross-repo use).
- **Import into LifeOS** via the `update-local-skills` flow.
- **Add to the org repo** (`~/work/org`) context/skills so shared reconciliation work can point at the same convention its `process-weekly-meeting` skill already half-embodies.

## Non-goals
- Not a heavyweight change-management process.
- Not a substitute for a repo's own dry-run / approval tooling.
- Not only for meetings — meeting reconciliation is one instance, not the scope.

## Open questions
- Whether `process-weekly-meeting` / `process-meeting` should later reference this skill rather than each restating the `D#`/`G#` convention.
- Whether a forward-test is warranted, or whether the skill is simple enough not to need one.
