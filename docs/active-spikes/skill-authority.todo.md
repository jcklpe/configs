# Skill Authority To-Do
Status: **active.** Cleanup done; the substantive work is untouched.

Conceptual doc: `docs/active-spikes/skill-authority.md`.

## Background
An agent rewrote five global skills into repo-local ones without being asked, breaking the position-independence property that lets one file serve as both the global skill and a vendored copy. Fixing that surfaced two adjacent inconsistencies: `docs/how-to-spike.md` duplicates `skills/run-project-spike/SKILL.md`, and this repo's flat `docs/` layout does not match the `docs/active-spikes/` layout its own skills describe.

## Project Organization
- `skills/setup-local-skills/SKILL.md` — gains an update path, loses step 8.
- `skills/*/SKILL.md` — audited for position-independence violations.
- `docs/how-to-spike.md` — deleted.
- `docs/active-spikes/` — new home for active spike pairs.
- `AGENTS.md`, `TODO.md` — references updated. (`CLAUDE.md` is a symlink to `AGENTS.md`; edit `AGENTS.md`.)

## General Principles
- Seed text states conditions. It never states facts about its own location.
- A verbatim copy of a global skill must be correct as a local skill. If it is not, the global text is wrong.
- Sync is one-way, agent-mediated, and always reviewed. Clobbering is allowed; silent clobbering is not.
- No metadata, no merge base, no versioning, no marker regions.
- Skill bodies are read by Claude, Codex, and Copilot. Canonical path is `~/configs/skills/`, never `~/.claude/skills/`.

## Current State Overview
The rogue diff is reverted and the tree is clean apart from this spike's new docs. `docs/active-spikes/` exists and holds the two new spike pairs, but `docs/lifeos-tools-v2.md` and its to-do are still flat under `docs/` — the migration item below.

`setup-local-skills` still contains step 8 and still has no update path.

## To Do
### Fix the skills
- [ ] Delete step 8 of `skills/setup-local-skills/SKILL.md` ("*Remove or rewrite the copied skill's `## Local Precedence` section...*"). Keep step 9 (the `AGENTS.md` local-precedence note).
- [ ] Remove the "deleting global-only `## Local Precedence` sections" bullet from that skill's `## After Copying` list.
- [ ] Add an `## Update Workflow` section to `setup-local-skills`: read global, read local, diff, summarize what changed upstream and how the local copy diverged, propose, apply on approval. No git, no metadata.
- [ ] Update the `description:` frontmatter of `setup-local-skills` so "update an existing local skill" is a trigger, not just "copy."
- [ ] Audit all six skills for position-independence violations and Claude-specific paths. The rogue diff hit five; check `track-changes` too, which it did not touch.

### Retire how-to-spike.md
- [ ] Read `docs/how-to-spike.md` once more and confirm nothing in it is missing from `skills/run-project-spike/SKILL.md`. Fold anything that is.
- [ ] Delete `docs/how-to-spike.md`.
- [ ] Update `AGENTS.md:61` (the "Where things go" table row) and `AGENTS.md:73` (the authority ladder paragraph).
- [ ] Update `TODO.md:37` ("Use `docs/how-to-spike.md` for spike workflow").
- [ ] Decide whether `skills/run-project-spike/SKILL.md:10` should keep its "*or a `how-to-spike.md` document*" clause for other repos. See open questions in the conceptual doc.

### Hoist personal rules to a global AGENTS.md
- [ ] Decide the source file. Something like `agents/AGENTS.global.md` in this repo, holding only cross-repo *personal* preferences: the Markdown and prose style rules, and nothing else.
- [ ] Symlink it from `install-script/functions/symlinks.sh` to `~/.codex/AGENTS.md` (Codex's documented global scope) and `~/.claude/CLAUDE.md` (Claude Code's user-level memory). Neither currently exists on this machine.
- [ ] Decide what happens to this repo's `## Markdown And Prose Style` section once the rules are global. Keep a pointer, drop the section, or accept the duplication? Codex concatenates root-down and nearest wins, so duplication is harmless but drifts.
- [ ] **Nothing repo-scoped may go in the global file.** The commit policy is `configs`-specific and belongs in `0003`, not in a file that applies to every repo on the machine. This is the position-independence rule again: a global file must not assert facts about "this repo."
- [ ] Check what GitHub Copilot actually reads for instructions. It picks up skills from `~/.claude/skills` (confirmed), but its instruction-file path is unknown and may be neither of the above.

### Migrate to docs/active-spikes/
- [ ] Move `docs/lifeos-tools-v2.md` and `docs/lifeos-tools-v2.todo.md` into `docs/active-spikes/`.
- [ ] Grep for every reference to those two paths and update. They are named in `TODO.md` and in `docs/archive/` (archive references may stay stale — archived docs are historical, not authoritative).
- [ ] Update the `AGENTS.md` "Where things go" table so the spike row points at `docs/active-spikes/<topic>.md`.
- [ ] Update the `TODO.md` notes section.
- [ ] Consider `docs/README.md` explaining the layout.

## Ready for Human QA
- None yet.

## Done
- [x] **Reverted the rogue skill edits** (2026-07-09). Saved the diff to a scratchpad patch first, since uncommitted changes exist nowhere else and `git restore` is unrecoverable. Then `git restore skills/`.
- [x] **Re-applied the one good hunk** from that diff by hand: `skills/triage-project-misc/SKILL.md` line 36, `Active spike docs in docs/` → `docs/active-spikes/`. That line was correct and consistent with `run-project-spike`; it was simply mixed in with four bad changes.

## Validation
No test suite. Validate by inspection and by use:

- After the `setup-local-skills` edit, read the skill start-to-finish as if you were an agent in a *different* repo. Nothing should claim authority it does not have.
- After the migration, `grep -rn "docs/how-to-spike" . --exclude-dir=.git` returns nothing outside `docs/archive/`.
- After the migration, `grep -rn "docs/lifeos-tools-v2" . --exclude-dir=.git` returns nothing outside `docs/archive/` and `docs/active-spikes/`.

## Known Edge Cases
- `CLAUDE.md` is a symlink to `AGENTS.md`. Edit `AGENTS.md`; never write through the symlink expecting two files.
- `docs/archive/` may reference old paths. That is fine — archived docs are historical context, not current rules. Do not rewrite history to match the new layout.
- The `skills/` directory in this repo is simultaneously the global library and this repo's local skills. That is not a bug; it is the position-independence property working.
