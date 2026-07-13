# Skill Taxonomy To-Do
## Current State
Opened 2026-07-13 from a conversation about LifeOS, `my-website`, and `configs` all needing the same routing taxonomy for pinned issues, future ideas, misc intake, decisions, active spikes, and skill feedback.

## To Do
None currently.

## Done
- [x] Promoted the skill-feedback loop note from `docs/scratch/misc.md` into this spike. The original note asked for a lightweight feedback loop short of strict TDD: log concrete skill friction, do not auto-apply, and triage periodically.
- [x] **Create/update global skills: `pin-issue`, `log-future-idea`, `log-skills-feedback`, `write-skills`, `update-local-skills`.** Done. `track-deferred-decisions` was renamed/split to `pin-issue`; `setup-local-skills` now points update work to `update-local-skills`.
- [x] **Add `agents/skills-feedback-log.md`.** Done. The log starts with the taxonomy/feedback-loop issue as the first open feedback item.
- [x] **Update coordinating global skills: `triage-project-misc`, `run-project-spike`, `setup-project-docs`, `setup-local-skills`.** Done. They now distinguish pinned issues, future ideas, misc intake, decisions, and active spikes.
- [x] **Rename configs register from `docs/deferred-decisions.md` to `docs/pinned-issues.md` and update references.** Done. Current configs links pass; historical archive references were left as historical text.
- [x] **Update symlink installer for renamed/new global skills and the feedback log.** Done, and refreshed current `~/.codex` / `~/.claude` symlinks for the new skill names.
- [x] **Update LifeOS vault local skills and docs to the new taxonomy.** Done. Added vault-local `pin-issue` and `log-future-idea`, renamed the register to `docs/pinned-issues.md`, added `docs/scratch/future-ideas.md`, split `docs/decisions.md` into individual records under `docs/decisions/`, and updated links.
- [x] **Update `my-website` local skills and docs to the new taxonomy.** Done. Added/updated local vendored skills, renamed the pin register, added the future-ideas workflow, and moved the footnote regression watch out of future ideas into misc.
- [x] **Validate skill frontmatter and key links.** Partial. Configs skill frontmatter passed a Ruby YAML check. Configs and LifeOS Markdown link checks pass. The official `quick_validate.py` could not run because the current Python environment lacks PyYAML. `my-website` has pre-existing archive link rot, so a whole-repo historical link check remains noisy.
