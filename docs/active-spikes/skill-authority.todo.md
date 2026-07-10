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
The skills are fixed, `docs/how-to-spike.md` is retired, and the repo is migrated to `docs/active-spikes/`. What remains is the global `AGENTS.md` folder, which has one undecided design question, and an optional `docs/README.md`.

## To Do
### Hoist personal rules to a global AGENTS.md
- [ ] Check what GitHub Copilot actually reads for instructions. It picks up skills from `~/.claude/skills` (confirmed), but its instruction-file path is unknown and may be neither of the above. Nothing in `symlinks.sh` targets it.


## Ready for Human QA
- None yet.

## Done
### Fix the skills
- [x] **Delete step 8 of `skills/setup-local-skills/SKILL.md` ("*Remove or rewrite the copied skill's `## Local Precedence` section...*"). Keep step 9 (the `AGENTS.md` local-precedence note).** Done. Replaced with a `## Why Verbatim Copies Are Correct` section explaining the position-independence property, so the deletion reads as a principle rather than an omission.
- [x] **Remove the "deleting global-only `## Local Precedence` sections" bullet from that skill's `## After Copying` list.** Done. Rewrote the section so local divergence appears when a project needs it, not as a copy-time ritual.
- [x] **Add an `## Update Workflow` section to `setup-local-skills`: read global, read local, diff, summarize what changed upstream and how the local copy diverged, propose, apply on approval. No git, no metadata.** Done, exactly as specified.
- [x] **Update the `description:` frontmatter of `setup-local-skills` so "update an existing local skill" is a trigger, not just "copy."** Done.
- [x] **Audit all six skills for position-independence violations and Claude-specific paths. The rogue diff hit five; check `track-changes` too, which it did not touch.** Done, seven skills now that `commit-work` exists. All clean: every `## Local Precedence` section is a condition rather than an assertion, and no skill body names a Claude- or Codex-specific path. One grep hit (`.claude/` in `setup-project-docs`) is a `.gitignore` entry, not a skill-source path.

### Retire how-to-spike.md
- [x] **Read `docs/how-to-spike.md` once more and confirm nothing in it is missing from `skills/run-project-spike/SKILL.md`. Fold anything that is.** Done. The skill strictly dominates it except for one paragraph: the repo-specific rationale for spiking at all (configs/ is personal and portable, so a change must answer more than "does it work?" — shell load order, public-repo safety, secrets, idempotency, startup cost). Folded into the `AGENTS.md` docs workflow section, since it is a fact about this repo rather than about the process.
- [x] **Delete `docs/how-to-spike.md`.** Done — and done wrongly the first time. See the `git rm` entry below.
- [x] **Update `AGENTS.md:61` (the "Where things go" table row) and `AGENTS.md:73` (the authority ladder paragraph).** Done. The table row was then edited again by the migration; two commits, two real states.
- [x] **Update `TODO.md:37` ("Use `docs/how-to-spike.md` for spike workflow").** Done.
- [x] **Decide whether `skills/run-project-spike/SKILL.md:10` should keep its "*or a `how-to-spike.md` document*" clause for other repos.** **Keep it.** Other repos may still carry a `how-to-spike.md`, and the clause is a condition, not an assertion — it stays true everywhere, which is exactly the property this spike is about. Retiring this repo's copy is not a reason to blind the skill to everyone else's.

### Migrate to docs/active-spikes/
- [x] **Move `docs/lifeos-tools-v2.md` and `docs/lifeos-tools-v2.todo.md` into `docs/active-spikes/`.** Done with plain `mv` plus a pathspec commit, not `git mv`. Git detected the rename anyway.
- [x] **Grep for every reference to those two paths and update. They are named in `TODO.md` and in `docs/archive/` (archive references may stay stale — archived docs are historical, not authoritative).** Done. Updated `TODO.md`, `AGENTS.md`, both scratch docs, and a doc comment in `lifeos-tools/lifeos.sh` that the original item did not anticipate. The eight archive references were deliberately left pointing at the old paths.
- [x] **Update the `AGENTS.md` "Where things go" table so the spike row points at `docs/active-spikes/<topic>.md`.** Done.
- [x] **Update the `TODO.md` notes section.** Done.
- [x] **Consider `docs/README.md` explaining the layout.** Done — a table of the four folders and their authority levels, plus a pointer to the process skills. Deliberately did **not** add `docs/active-spikes/README.md`, even though every sibling folder has one: it would list the spikes currently in flight, and `TODO.md` is already that index. A second index drifts.

### Hoist personal rules to a global AGENTS.md
- [x] **Decide the source file. Something like `agents/AGENTS.global.md` in this repo, holding only cross-repo *personal* preferences: the Markdown and prose style rules, and nothing else.** Done, at exactly that path. The name matters: Codex loads every file *literally named* `AGENTS.md` from repo root down to the working directory, so `agents/AGENTS.md` would be pulled in a second time by anyone working inside that folder, on top of the repo's own. `AGENTS.global.md` is invisible to that walk.
- [x] **Symlink it from `install-script/functions/symlinks.sh` to `~/.codex/AGENTS.md` (Codex's documented global scope) and `~/.claude/CLAUDE.md` (Claude Code's user-level memory). Neither currently exists on this machine.** Done, with `ensure_dir` for both parents, and the symlinks created directly so they are live without a full installer run.
- [x] **Decide what happens to this repo's `## Markdown And Prose Style` section once the rules are global. Keep a pointer, drop the section, or accept the duplication?** **Keep the full text in both**, per the user. `AGENTS.md` reads completely on its own, which matters for anyone browsing the repo on a forge. Both copies now carry a "edit both, or neither" note naming the other, because the repo copy silently wins when they disagree and drift would be invisible.
- [x] **Nothing repo-scoped may go in the global file.** Held. The global file states preferences only, and opens by saying why: it is read from inside every project, so "this repo" resolves against whichever repo is being worked in. The commit policy stays in `0003`. Hoisting it would have authorized agent commits in every repo on the machine — the same deictic failure that opened this spike, one level up.

### Unplanned
- [x] **`git rm` and `git mv` stage, and `commit-work` did not know it.** Discovered by using `git rm` to delete `docs/how-to-spike.md` — a direct violation of the never-stage rule, committed before it was noticed. The skill had no guidance for deletions or renames at all, so an agent following it to the letter would reach for `git rm` the first time it needed to remove a file. Verified the correct primitives: plain `rm` followed by `git commit -- <path>` records a deletion with the index untouched; a rename is plain `mv`, one guarded `git add` for the now-untracked new path, then a pathspec commit naming both. Git still detects the rename. Added to `commit-work` as an iron rule, a `## Deletions And Renames` section, two rationalization rows, and a red flag.

- [x] **The `.todo.md` updates lagged their work commits.** `run-project-spike` says the item's `.todo.md` edit belongs in the same commit as the work it describes. The skills fix, the how-to-spike retirement, and the migration were each committed without moving their items, and this entry is part of the catch-up. Nothing was lost, but the commits do not individually show what they were for. The rule was written this morning; following it takes more than writing it.
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
