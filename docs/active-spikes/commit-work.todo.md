# Commit Work To-Do
Status: **active.** Nothing implemented yet. Design is settled; see the conceptual doc.

Conceptual doc: `docs/active-spikes/commit-work.md`.

## Background
`gitall` (in `git/git.sh`) is a sweep-all-and-push helper. It produces one large commit per work session, with a message that necessarily describes several unrelated things. This spike replaces it *for spike work* with a `commit-work` skill that commits by pathspec, at completion boundaries, with a `Spike:` trailer.

The design was worked out in conversation on 2026-07-09. The conceptual doc records the settled model and the rejected alternatives; this doc tracks execution.

## Project Organization
- `skills/commit-work/SKILL.md` — the new skill. Global (symlinked into `~/.claude/skills`, Codex, and Copilot via `install-script/functions/symlinks.sh`).
- `skills/run-project-spike/SKILL.md` — gains calls to `commit-work` at the completion boundary and at archival. Does **not** learn how to write commit messages.
- `docs/decisions/0003-agent-commit-policy.md` — the durable rule.
- `git/git.sh` — **untouched.** `gitall` is explicitly out of scope.

## General Principles
- The agent commits. The agent never pushes.
- `git commit -m "msg" -- <explicit paths>`. Never `git add`, never a bare `git commit`, never `-a`.
- Never `--amend`, never rebase, never force-push.
- Commit when the implementation is finished and self-verified, not when the item reaches `Done`.
- The `.todo.md` edit ships in the same commit as the work it describes.
- Within the spike's file scope, split and commit silently. Outside it, stop and ask.
- If a one-line summary needs the word "and," it is two commits.

## Current State Overview
Nothing built. The rogue-agent skill edits that were dirty in the tree at the start of this conversation have been reverted (that cleanup belongs to the `skill-authority` spike, where it is recorded).

The repo now uses `docs/active-spikes/` throughout; the migration landed as `skill-authority` work on 2026-07-10.

## To Do
- None. The spike is complete.

## Ready for Human QA
- None. The three items here passed on 2026-07-09; see Done.

## Done
- [x] **Use `commit-work` on the `skill-authority` spike as it proceeds. If the workflow is annoying there, it will be annoying everywhere.** Done — fifteen commits across that spike, and it was not annoying. It was, twice, actively useful: it caught that my own six-commit plan was really eleven, and it refused to let `git rm` pass unexamined.

- [x] **Watch the frequency of forced "and" commits over the next few spikes. Two out of eleven on the first run is acceptable and both were index/rules files; if it climbs, commits are too rare.** Measured over thirty commits. Six subjects contain the word "and"; only **four** are genuinely two changes trapped in one file (`AGENTS.md`, `TODO.md`, `setup-local-skills`, `skill-authority.md`). The other two — `forbid git rm and git mv`, `add gitcommit and gitpush as the two halves of gitall` — are single changes with compound objects.

  So the frequency is fine (4/30, all file-level entanglements), but the *test itself was stated wrong*: the skill said "if the summary needs the word and, it is two commits," when the real test is whether the "and" joins two **changes** or two objects of one change. A grep for the word over-fires. Corrected in the iron rule, the scoping section, and the red flag, with both worked examples. This is the durable lesson from measuring rather than assuming. (2026-07-10, commits `bb2aca9`..`44fb81d`). Split a 34-path tree spanning four themes into eleven commits. The plan going in called for six; applying the "and" test honestly during execution split the largest one further, because it had bundled the skill, its symlink registration, the decision record, the `run-project-spike` wiring, and the spike docs under a single subject. Only two commits kept a forced "and", both index/rules files (`AGENTS.md`, `TODO.md`), both with bodies explaining the entanglement. `TODO.md` carries two `Spike:` trailers.

  Verified afterward: `git log --grep='Spike: commit-work$' --reverse` returns the spike's eight commits in order, `skill-authority` returns three, and `TODO.md`'s dual trailers both parse. The trailer index works.

- [x] **The concurrency hazard fired for real, and the design held.** Mid-commit-sequence, the user edited `git/git.sh` to add a `gitpush` function, unprompted and unannounced. Nothing coordinated; nobody checked. Under `gitall` or `git commit -a`, those six in-progress lines would have landed inside "todo: index new spikes and deferred-decisions register" under the wrong message and the wrong trailers. Under the pathspec rule, zero of the eleven commits touched the file and the work stayed in the tree. This was not a test we designed. It happened by itself, roughly twenty minutes after the rule was written down, and it is the single strongest evidence in this spike.

  `commit-work` then surfaced `git/git.sh` as stray work outside the spike's scope and asked rather than sweeping, which is the behavior the "silent inside scope, ask outside scope" rule exists to produce.

- [x] **Human QA passed** (2026-07-09). The user read `skills/commit-work/SKILL.md`, made small edits directly, and judged the rules sound. They declined to rule on whether the rationalization table names real excuses, on the grounds that an LLM is the better witness there. The skill surfaces correctly in a live session. Message format confirmed after two rounds of revision.

- [x] **Discovered that commit granularity is file-level.** Found while planning this spike's own first commit, which is exactly what the dogfooding was for. `AGENTS.md` had accumulated two unrelated changes — the `0003` policy pointer and the Markdown style rule — and a pathspec commit takes whole files, so they cannot be separated without `git add -p`, which stages, which the iron rules forbid. This is a floor beneath the "and" test, not a contradiction of it: **a file holding two unrelated changes means the agent waited too long to commit.** Written into the skill as `### Granularity is file-level, and that is the point`, with an ordered fallback (commit together and say so; if large and unrelated, ask the human) and a new rationalization row refusing `git add -p`.

- [x] **Fixed the completion-boundary framing.** The first draft said commit "when you would say *this is ready for you to look at*," which quietly teaches an agent that the boundary sits just before human QA. The user pointed out that most items go `To Do → Done` directly and never see QA, so that framing would have withheld commits on the majority of work. Corrected in the skill, in `run-project-spike`, and in the conceptual doc, with the sentence "Human QA is the exception, not the path." The wrong first draft is recorded so it is not reintroduced.

- [x] **Restyled to compact heading spacing.** The user's Markdown preference (no blank line between a heading and its content) was stated too narrowly in `AGENTS.md` — the old rule only covered *adjacent headings*, and its "follow existing file style" clause actively pointed at the airy form used by the five older skills. Rewrote the rule to say what was meant, then normalized all 29 tracked Markdown files with a fence- and frontmatter-aware script. Verified whitespace-only: 255 blank lines removed, zero non-blank lines added outside files already being edited. The reformat is stray work relative to both spikes and gets its own untrailered commit.

- [x] **Verified pathspec-commit semantics empirically** (2026-07-09, git 2.39.5 Apple Git-154, macOS). Ten cases, run from a throwaway repo. The whole safety argument rested on assertions nobody had tested. Five held; three details were wrong; one finding was worse than expected.

  Held:
  - `git commit -m x -- b.txt` with `a.txt` staged commits **only** `b.txt`, and leaves `a.txt` staged. The index is genuinely bypassed for the paths not named.
  - Untracked path → `error: pathspec 'c.txt' did not match any file(s) known to git`, exit 1.
  - Gitignored path → cannot be committed by pathspec at all.
  - Worktree content wins over staged content for a pathspec'd path.
  - Five rounds of two truly simultaneous pathspec commits: **zero contamination.** Every commit contained exactly its own paths.

  Wrong, and corrected in the conceptual doc:
  - The concurrency lock is **`.git/index.lock`**, not a ref lock. Pathspec commits still take the index lock. Exit 128, `fatal: Unable to create ... index.lock`. The loser's changes stay in the worktree; a retry succeeds. Collisions occurred in 4 of 5 rounds when the two commands were fired simultaneously — far from rare under true concurrency.
  - A **stale** `index.lock` (killed process) produces a **byte-identical** error to a live collision. Blind retry-on-128 loops forever.
  - A pathspec commit naming a tracked-but-unmodified file exits **1** with `nothing to commit, working tree clean`. A benign no-op looks like a failure.

  The bad one:
  - Untracked and gitignored paths fail with **identical** messages, so the error alone cannot distinguish them. `git check-ignore -q <path>` (exit 0 = ignored) is the required pre-flight guard before any `git add`.
  - Plain `git add <ignored>` correctly refuses, exit 1 — **but prints `hint: Use -f if you really want to add them.`** And `git add -f <ignored>` then stages it silently, exit 0. Git advertises the secret-leak path in the error message an agent is most likely to encounter while adding a legitimate new file. `git add -f` is now a named, explicitly-refused rationalization in the skill.

  Script preserved at `scratchpad/pathspec-test.sh` for the session; not committed. Findings are folded into the conceptual doc's "Failure modes are not interchangeable" table, which is the durable artifact.

- [x] **Verified the commit invocation form** (same session). `git commit -F - -- <paths> <<EOF` accepts a heredoc message alongside a pathspec. `Spike:` and `Co-Authored-By:` both parse as real trailers (`git log --format='%(trailers:only=true)'`). `git log --format='%(trailers:key=Spike,valueonly=true)'` extracts the slug as structured data, which is nicer than grepping. Confirmed that `--grep='Spike: foo'` matches `Spike: foo-extra` too, and that `$`-anchoring fixes it — so the anchored form is the one documented in the skill.

- [x] **Write `skills/commit-work/SKILL.md`. Must cover: scope detection, the "and" test, pathspec-only rule, the untracked-file exception, trailer format, when to ask vs commit silently, confirm-before-commit when there is no spike context, and an explicit prohibition on push/amend/rebase.** Done. Also grew a five-way failure-mode table and a `### Granularity is file-level` section that were not anticipated.

- [x] **Include the rationalization table from the conceptual doc's "Writing The Skill Itself" section verbatim in the skill. Add any new excuses observed while using it.** Done, thirteen rows. Two were added later from live observation: the `git add -p` escape when one file holds two changes, and building the pathspec from `git status` output. One row from the original draft was cut as theatre (`git add .` followed by a pathspec commit) — an agent would not actually land on that compound move.

- [x] **Write the `description:` frontmatter so it leads with triggering conditions, not a workflow summary, and so it contains the words an agent thinks right before violating the rule: `git add`, `gitall`, `push`, `amend`, `commit -a`.** Done. Technique borrowed from the Superpowers `writing-skills` guide.

- [x] **Registered the skill globally.** Added `commit-work` to both the Codex and Claude blocks of `install-script/functions/symlinks.sh`, and created the two symlinks directly so it is live without a full installer run. GitHub Copilot has no block of its own and needs none: asked directly, it reports reading global skills from `~/.claude/skills`, which `symlinks.sh` already populates. (It said so while running a Codex model, which is odd but works.) No action needed.

- [x] **Revised the message format** after review. The first draft said "body: **why**, not what," which is standard advice that assumes commits large enough to have a why. Spike items are atomic; the modal commit here is subject-only. Worse, an agent handed a "body" field will fill it, confabulating a rationale then indistinguishable from a real one forever. Default inverted to subject-only.

- [x] **Wire `run-project-spike` to invoke `commit-work` at the completion boundary, passing the spike slug.** Done, as a new `## Committing Spike Work` section. Kept **policy-neutral**: `run-project-spike` is a global skill used in repos that may forbid agent commits, so it says to follow the repo's own policy and, *if the repo says nothing, not to commit and not to offer*. This repo's `0003` is what switches it on. It writes no commit logic and no messages; it hands `commit-work` the slug and gets out of the way.

- [x] **Wire `run-project-spike` to invoke `commit-work` at archival, with the synthesis message and the doc moves.** Done, as `### The Archival Commit` under the archiving steps. The archival *is* a commit — the doc moves are its diff — so its message is the spike summary, and it is the one commit a human reviews before it lands. Synthesis, not rollup: dead ends leave no trace in the tree.

- [x] **Teach `run-project-spike` that QA approvals produce a doc-only commit, batched per QA event.** Done. One approval is one commit, however many items it covered.

- [x] **Preserve item granularity when moving work to `Done`.** *(Unplanned; added 2026-07-10 after the user asked whether Done entries were over-synthesized. They were.)* Six `To Do` items had been collapsed into two `Done` entries — the three `run-project-spike` wiring items into one, and the skill/table/description items into another. The history survived; the *plan* did not, which is what makes the history checkable. Restored the six original item lines above, and added a `### Moving An Item Preserves It` rule to `run-project-spike`: one item in, one entry out, original wording carried across, unplanned work gets its own entries, dropped items are marked dropped rather than deleted.

  A related hole, worth naming: this spike's `.todo.md` was not committed until the work was finished, so its `To Do → Done` transitions exist nowhere in git. The original list survived only because it was still in the session's conversation. Committing at each completion boundary would have captured every transition. The first spike could not do that, because `commit-work` did not exist yet. Every spike after this one can.

- [x] **Wrote `docs/decisions/0003-agent-commit-policy.md`.** Records the rule, not the how — reversibility as the approval line, pathspec-only, no `add -f`, no rewriting, no pushing, completion boundary, the "and" test, silent-in-scope. Notes explicitly that it supersedes the prior "agents never commit" rule *including any stored agent memory that still asserts it*, and that `gitall` is unchanged but must not be run while an agent works.

- [x] **Added the `AGENTS.md` pointer.** A new `## Git and commits` section plus a row in the "Where things go" table. Written unwrapped, per that file's own convergence rule, without reflowing the hard-wrapped paragraphs around it.

- [x] **Rewrote the agent memory.** Deleted `git-commits-user-handled.md`, whose slug and description both asserted the opposite of current policy, and wrote `git-commit-policy.md` in its place with the pathspec rule, the `add -f` trap, and the reversibility rationale. Updated `MEMORY.md`. Scoped to `~/configs`: outside it, an agent should still assume commits are forbidden unless that repo says otherwise.

- [x] **Reversed the wrapping rule, twice.** Draft one deferred to the repo's no-hard-wrap prose rule. Draft two overrode it with "wrap at 72," on the grounds that git prefixes every literal line and a soft wrap collapses the paragraph's indent — demonstrated, and true. Draft three reverted to no-hard-wrap after the user pointed out the defect is purely cosmetic, that hard-wrapped text is correct at exactly one width and ragged at every other, that these commits will mostly be read on a code forge, and that `AGENTS.md`'s rule is not about Markdown at all but about formatting being the client's job. That principle covers plain text consumed at many widths better than it covers Markdown. Kept: the blank line before the body and the trailing trailer block, which git parses and which are therefore not formatting. Reasoning preserved in the conceptual doc under "Most commits have no body," including the losing argument, so nobody relitigates it from scratch.

## Validation
There is no test suite. Validate by using it:

- Build `commit-work`, then use it to commit the `skill-authority` spike's work. If it is annoying there, it will be annoying everywhere.
- Check `git log --grep='Spike: skill-authority' --reverse` returns a readable narrative of that spike.
- Confirm no commit produced by an agent contains a file outside the spike's scope.

## Known Edge Cases
- **Untracked files** need `git add` before a pathspec commit can see them. This is the only moment the shared index is touched. Do not run `gitall` in a repo where an agent is working.
- **Concurrent agents** are safe under the pathspec rule, but the ref-lock race means a commit can fail loudly. `commit-work` should retry once rather than surfacing a scary error.
- **Two agents on the same file** is unhandled. Currently a human scheduling problem; flagged as an open question in the conceptual doc.
- **A dirty tree at spike start** is stray work. Ask, do not sweep.

## Public Safety And Secrets
`commit-work` stages nothing and commits only named paths, which reduces the risk of sweeping a `.env` or a token file into a commit. It should still refuse to commit a path matched by `.gitignore` and should say so loudly rather than silently skipping. See `docs/decisions/0001-secrets-and-local-env.md`.
