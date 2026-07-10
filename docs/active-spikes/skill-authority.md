# Skill Authority
Status: **active spike.** Opened 2026-07-09 after an agent silently rewrote five global skills into repo-local ones.

Companion to-do: `docs/active-spikes/skill-authority.todo.md`.
Sibling spike: `docs/active-spikes/commit-work.md` (same conversation, separate subject).

## Purpose
Make this repo's process artifacts and its skill library agree about **which copy of a skill is authoritative, and where**. Three things currently disagree: the global skills describe themselves inconsistently, `docs/how-to-spike.md` duplicates a process that `skills/run-project-spike/SKILL.md` now owns, and the repo's own docs layout does not match the layout its skills describe.

## Background: The Incident
At the start of the 2026-07-09 conversation, five skills in `skills/` had uncommitted modifications that the user did not make and did not authorize. Every one had its `## Local Precedence` section rewritten from a conditional into an assertion:

```diff
-If the current repo already has `skills/run-project-spike/SKILL.md`, read and follow the
-repo-local skill first. Treat this global skill as fallback seed material.
+This is the repo-local `run-project-spike` skill. Treat it as authoritative for
+this repository.
```

The same diff also hard-wrapped its new prose at ~72 columns and reflowed a neighboring paragraph, both of which `AGENTS.md` explicitly forbids. Whatever wrote it was not reading the rules while editing the files that *are* the rules.

The changes were reverted. A copy of the discarded diff was kept during the session for reference; it is not committed and is not needed.

## The Insight: Position Independence
`skills/` is not a template directory. It holds the **live global skills**, symlinked into `~/.claude/skills/`, Codex, and Copilot by `install-script/functions/symlinks.sh`. Copying one into another repo is not forking a template — it is **shipping the process alongside the code**, so that whoever clones the repo can develop the way the repo was built. The copy is a distribution artifact, and it is also allowed to diverge locally as the project's needs sharpen.

That double role is only survivable if the skill's text is **position-independent** — true regardless of which copy is being read.

The original wording had this property:

> If the current repo already has `skills/<name>/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

Read from the global copy, it defers to the local one. Read from the local copy, it refers to itself and is trivially satisfied. **The same bytes are correct in both places.**

The rewrite destroyed that property, because "this repository" is *deictic* — it resolves against whatever repo the agent is reading from, not against the file's location on disk. A global skill asserting it is "authoritative for this repository" hijacks every project it is invoked in and tells the agent to ignore that project's actual local copy.

The general rule that falls out:

> **Seed text states conditions. It never states facts about its own location.**

And a useful corollary: because verbatim copies are already correct, step 8 of `setup-local-skills` (*"remove or rewrite the copied skill's `## Local Precedence` section"*) is not a helpful adaptation. It is the step that **creates** the divergence that then needs reconciling. Deleting step 8 makes a verbatim copy lossless by construction.

## Settled Model For Skill Sync
The user's actual requirements, in their words:

1. Pull changes **down** from global skills, for when a change made globally is worth adopting locally.
2. Keep the ability to **diverge and evolve** a skill in a local repo context.
3. Keep a **local distribution artifact** so collaborators who clone the repo get the process.

Notably absent: pushing local changes back upstream. This is a one-way sync.

So the skill is small: an agent reads the global `SKILL.md`, reads the repo's copy, works out what changed upstream, applies it to the local copy while leaving intentional local divergence alone, and reports what it did. The user reviews the result.

**No metadata. No merge base. No git.** Earlier drafts of this design proposed a `synced_commit` frontmatter stamp to enable a real three-way merge, marker regions (`<!-- local:begin -->`) to protect local edits, and semantic versioning of skills. All three were rejected. They exist to let a merge run *unattended*; this one never does. The user is in the loop, the sync happens a handful of times a year, and when an upstream change collides with a local divergence, the answer is to read both and decide.

Clobbering the local version entirely is a legitimate outcome. The skill holds no policy about it. Its job is to **surface** the divergence, so that overwriting is never the *silent* outcome.

This becomes an update path inside `setup-local-skills` rather than a separate `update-local-skills` skill. Step 7 of that skill (*"do not overwrite an existing repo-local skill without... explicit approval"*) is already the seam where update belongs; it is currently a stub. Two skills would mean duplicating the substantive content, which is the adaptation guidance, not the file copy.

## Also In Scope
Two cleanups follow from the same theme — making the repo's own artifacts consistent with what its skills describe.

**Retire `docs/how-to-spike.md`.** It is the ancestor artifact that `skills/run-project-spike/SKILL.md` was distilled from. Until this week the user's workflow was to copy-paste and adapt it per project; the skill now does that job properly. Keeping both means two documents describing one process, with `AGENTS.md` naming the wrong one as authority. Delete it and update the four references.

**Migrate `docs/` to `docs/active-spikes/`.** `run-project-spike` describes an `docs/active-spikes/` layout and instructs agents to preserve a repo's flat convention unless the user is deliberately migrating. The user is deliberately migrating. `docs/lifeos-tools-v2.md` and its to-do move; `TODO.md` and `AGENTS.md` update to match.

**Hoist personal rules to a global `AGENTS.md`.** The Markdown and prose style rules are *personal* preferences that currently live in a *project* file, so they bind only inside this repo. Agents working anywhere else have never heard of them. Codex reads a global `~/.codex/AGENTS.md`, concatenating root-down with nearest-wins precedence; Claude Code reads `~/.claude/CLAUDE.md` as user memory. Neither exists on this machine. Symlinking a seed file from this repo into both is the same pattern `symlinks.sh` already uses for skills, and it is the same authority question this spike is about: what is globally true, what is repo-local, and how does one not silently claim to be the other.

The constraint that falls out is the position-independence rule again, applied to instruction files: **a global `AGENTS.md` may not assert facts about "this repo."** The commit policy belongs in `0003` and must never be hoisted, however tempting it looks.

## Non-Goals
- No pushing local skill changes back up to global. If a local adaptation turns out to be good, moving it upstream is a manual, deliberate act.
- No versioning scheme for skills. No `synced_commit`, no semver, no content hashes.
- No marker regions or protected blocks inside `SKILL.md` files.
- No automated, unattended sync. Every sync is a conversation.
- No changes to how skills are symlinked in `install-script/functions/symlinks.sh`.

## Constraints
These skills are read by Claude, Codex, and Copilot. Do not add frontmatter keys beyond what all three tolerate, and do not name a Claude-specific path (`~/.claude/skills/`) in a skill body — the canonical location is `~/configs/skills/`. The rogue diff got this wrong too.

`AGENTS.md` forbids hard-wrapping prose and forbids reflow-only diffs. It applies to skill files.

## Relationship To Other Spikes
Born from the same conversation as `docs/active-spikes/commit-work.md`. The subjects do not overlap; they are siblings, not phases, so no continuation markers.

Sequencing: build `commit-work` first, then use it to commit this spike's work. This spike is small enough to be a good dogfooding test of that workflow.

## Settled
`skills/run-project-spike/SKILL.md` **keeps** its "*or a `how-to-spike.md` document*" clause, even though this repo no longer has one. The clause is a condition rather than an assertion, so it stays true in every repo, and other projects may still carry that file. Retiring one repo's copy is not a reason to blind the skill to everyone else's — which is the same position-independence argument this whole spike is built on, pointed at a clause instead of a header.

`setup-local-skills` reports **how** the local copy diverged, not merely that it did. The report is the whole value of the update path; a bare "these differ" would send the user to read both files anyway.

## Open Questions
- Does `docs/` want a `README.md` explaining the layout, as `run-project-spike`'s directory sketch implies?
- **Should the `description:` fields be rewritten to lead with triggers instead of feature inventories?** A skill's description is always in the agent's context; its body loads only when invoked. So the description is the expensive field, and it exists to answer "should I load this right now?" Several of ours open with a workflow summary and only reach the trigger at the end — `run-project-spike` spends 46 words listing its features before it says "Use when starting, continuing, promoting...". The Superpowers `writing-skills` guide argues, plausibly, that an agent skimming a description may act on the summary instead of loading the skill. This is a mechanical, low-risk edit to six frontmatter lines, but it is a change to how every skill announces itself and should be made deliberately rather than swept in with the authority fixes.
