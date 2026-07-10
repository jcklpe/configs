# Commit Work
Status: **active spike.** Opened 2026-07-09 from a design conversation about making git history a first-class artifact of spike work.

Companion to-do: `docs/active-spikes/commit-work.todo.md`.
Sibling spike: `docs/active-spikes/skill-authority.md` (same conversation, separate subject).

## Purpose
Today this repo's git history is produced by `gitall` — a sweep-everything-into-one-commit-and-push helper. It works for a solo dev who never reads their own history. It fails at three things the user now wants: collaborating with other humans, supporting future git archaeology, and generating source material for written case studies about how work actually went.

This spike adds a `commit-work` skill and wires it into `run-project-spike` so that spike work produces small, well-scoped, well-described commits that are traceable back to the spike doc that explains them.

## Goals
- A `skills/commit-work/SKILL.md` that turns a dirty working tree into one or more correctly-scoped commits with real messages.
- Commits that are safe to produce while two agents work concurrently in the same clone.
- A `Spike:` trailer that links every commit back to the spike that produced it.
- An archival commit whose message is a genuine synthesis of the spike, not a rollup of its parts.
- A durable decision record so future agents inherit the policy instead of relitigating it.

## Non-Goals
- The agent never pushes. Ever. Push stays a human action.
- No changes to `gitall`. It is not being fixed, guarded, or deprecated with a warning. It is being left alone to fall out of use on its own.
- No branch-per-spike. Spikes are a docs concept, not a git-branching concept.
- No history rewriting. No `--amend`, no interactive rebase, no force-push. Another agent may already have built on a commit.
- No commit signing, hooks, or CI integration in this spike.

## Vocabulary
- **The index** (a.k.a. the staging area): git's shopping cart. A single file at `.git/index`, shared by every process touching the clone.
- **Pathspec commit**: `git commit -m "msg" -- path/one path/two`. Commits the working-tree content of exactly those paths, bypassing the index entirely.
- **Bare commit**: `git commit -m "msg"` with no paths. Commits whatever is in the index. This is the dangerous form.
- **Completion boundary**: the moment an agent finishes an implementation and has verified it as far as it can from the terminal. This is when a commit happens.
- **QA event**: one human approval, covering however many items the user blessed in that breath. One QA event is one commit.
- **Trailer**: a `Key: value` line at the end of a commit message body. This spike introduces `Spike: <slug>`.

## Settled Model
### Reversibility decides who approves
The instinct to review every commit is wrong, and the instinct to review none of them is also wrong. The right line is not importance, it is **reversibility**. An unpushed local commit costs nothing to undo. A push is irreversible in practice, because someone else may have pulled it.

So: the agent commits freely during a spike, without asking. The agent never pushes. The user reviews at push time, and the whole unpushed window is the review window.

### Never stage; always pathspec
The index is repo-global shared mutable state. If agent A runs `git add` and agent B runs a bare `git commit` a second later, **B's commit silently contains A's files, with B's message and B's `Spike:` trailer.** No error, no conflict, no warning. This is the failure mode that makes naive agent commits unusable in a two-agent workflow.

The fix is structural, not procedural: **never stage anything.** Always `git commit -m "msg" -- <explicit paths>`. Two agents running pathspec commits at the same instant cannot contaminate each other. Worst case, one loses a race for `.git/index.lock`, dies loudly with exit 128, and retries. Loud failure is acceptable; silent wrong history is not.

This means the agent does not need to space out its commits, coordinate with other agents, or check whether anyone else is working. The safety is a property of the command, not of the timing.

**The one exception**: a brand-new, untracked file is invisible to git until `git add` tells git it exists, and there is no way around that. For the moment between `git add newfile` and `git commit -- newfile`, that file sits in the shared index. It only matters if some *other* process runs a bare commit in that window. Since `commit-work` never does, the window is closed by convention. `gitall` is the sole remaining thing that could open it, which is one more reason it should not be run in a repo where an agent is working.

If this ever bites in practice, `GIT_INDEX_FILE` pointed at a temp file gives each agent a private index. Do not build that until it breaks.

### The `git add -f` trap
A pathspec commit cannot commit a `.gitignore`d file: git reports `did not match any file(s) known to git`, exactly as it does for any untracked file. Plain `git add` on an ignored file also refuses — **but it refuses with a hint that names the workaround**:

```text
hint: Use -f if you really want to add them.
```

And `git add -f` obliges, silently. That is the one command in this whole design that can put a `.env` or an OAuth token into history, and git advertises it in the error message an agent is most likely to hit while trying to add a legitimate new file.

Two consequences, both load-bearing:

- `commit-work` must **never** run `git add -f`, `git add --force`, or `git commit --no-verify`. This is not a preference. See `docs/decisions/0001-secrets-and-local-env.md`.
- Because untracked and ignored files fail *identically*, the agent cannot learn which it is from the error. It must run `git check-ignore -q <path>` **before** deciding to `git add` a new file. Exit 0 means ignored: refuse, and say so out loud.

### Failure modes are not interchangeable
Empirically verified against git 2.39.5 on 2026-07-09 (`scratchpad/pathspec-test.sh`); the details matter because they are easy to conflate and each demands a different response:

| Situation | Result | Correct response |
| --- | --- | --- |
| Concurrent commit, lock held | `fatal: Unable to create ... index.lock` (128) | Retry, briefly and boundedly |
| **Stale** lock from a killed process | **the identical message** (128) | Surface to the human; do not loop |
| Path is untracked | `did not match any file(s)` (1) | `git check-ignore` first, then `git add` |
| Path is gitignored | **the identical message** (1) | Refuse loudly. Never `-f` |
| Path is tracked but unmodified | `nothing to commit` (1) | Benign. Not an error, not a retry |

A blind retry-on-nonzero loop gets two of these five catastrophically wrong.

### Commit at completion, not at Done
`run-project-spike` moves items `To Do → Ready for Human QA → Done`. In practice the user often blesses work conversationally ("looks good, consider it passing human QA") days after the agent finished, and increasingly does not read the to-do doc at all. `Done` is therefore a **bookkeeping** transition, not a work transition.

If the commit waited for `Done`, finished code would sit uncommitted for days in a tree another agent is also writing to. So the commit happens at the **completion boundary** — when the agent finishes and would say either "this is ready for you to look at" or "this is done, I confirmed it myself."

Which bucket the item then lands in is a separate decision, made afterward, and it does not move the commit. **Most items go straight from `To Do` to `Done`**; human QA is the exception, not the path. An early draft of the skill framed the boundary as "just before human QA," which was wrong and would have taught agents to hold commits back on the majority of work. The commit records the to-do doc in whatever state it genuinely is at that moment. That is honest.

The `.todo.md` edit that moves the item belongs **in the same commit** as the work it describes. This makes each commit self-describing: one commit shows both the change and the recorded intent behind it.

### QA approvals are their own commits
When the user approves work, the agent moves items to `Done` and commits that doc-only change. This is not noise. It records **when the human blessed it**, a timestamp that exists nowhere else — not in the diff, not in the implementation commit. The gap between the implementation commit and the QA commit is real data about how the work went.

Batch by QA event, not by item. When the user looks at three things and says "all good," that is one commit, because one approval happened.

### If QA fails, commit a fix
Never amend. A failed QA produces a new commit ("fix embed block overflow found in QA"). That the fix exists is itself worth recording — it shows QA doing its job.

### The trailer is a bare slug
Every commit produced inside a spike carries a trailer:

```text
Spike: commit-work
```

Bare slug, not a path. Paths change when a spike archives (`docs/active-spikes/x.md` becomes `docs/archive/x.md`) and commit messages are immutable. The slug is stable forever.

This makes git queryable along the same axis the docs are organized:

```sh
git log --grep='Spike: commit-work' --reverse
```

Reading a commit tells you which spike doc explains it. Reading a spike doc gives you the string that finds its commits. Anchor with `--grep='Spike: misc-3$'` if slugs ever prefix one another.

The slug is **passed in** by `run-project-spike`. When `commit-work` is invoked directly and more than one spike is active, it asks rather than guessing. A missing trailer is trivially fixable before push; a wrong trailer silently poisons the query.

This is the same instinct as the `🔗 Continues in:` / `🔗 Continues from:` marker comments that `lifeos-tools`' `trello supersede` writes between cards, pointed at git instead of Trello.

### Splitting: the "and" test
If an honest one-line summary of the commit needs the word "and," it is two commits.

Concretely, a dirty tree might hold:

```text
skills/commit-work/SKILL.md              (new)
skills/run-project-spike/SKILL.md        (modified — calls commit-work)
docs/active-spikes/commit-work.todo.md   (modified — item moved)
movement/movement.sh                     (modified — an `lk` fallback fixed days ago and forgotten)
```

The first three are one change. The fourth is stray. `gitall` produces one commit and a message that must say "add commit-work skill **and** fix lk fallback." `commit-work` produces two, and only the first gets a `Spike:` trailer, because only the first is spike work.

### What the pathspec rule costs, and why the cost is a feature
Pathspec commits take whole files, so two unrelated changes in one file cannot be separated. This was discovered while planning this spike's own first commit — the dogfooding working as intended.

It is not a defect. Hunk-splitting fabricates commits representing states that **never existed on disk and were never run**; in a shell-config repo that means committing a `path.sh` nobody ever sourced, and bisecting into it later. Whole-file commits guarantee every commit is a state that actually existed and was actually verified. The rule enforces something worth wanting.

Three consequences, all learned the hard way here:

- **Index and rules files are chronically entangled.** `TODO.md` and `AGENTS.md` are touched by every theme by their nature. They get their own commit, an honest "and" in the subject, and *every* relevant `Spike:` trailer — git parses repeated trailer keys and each spike's anchored `--grep` still finds the commit. Verified 2026-07-09.
- **Format passes must be committed alone, on a clean tree, before other work.** A repo-wide pass touches every file and therefore collides with every theme in flight simultaneously. This spike's 29-file heading reformat was run on a dirty tree and contaminated four files that had substantive changes pending. Do it first, or do it after.
- **The "and" is a tripwire, not a style.** It exists to make an agent notice it is about to build an incoherent commit. Licensing it whenever a file forces it disarms it. So it is permitted, it requires a body explaining why the changes could not be separated, and its *frequency* is the alarm: frequent "and" commits mean commits are too rare.

### Silent in scope, ask out of scope
The spike knows its own file scope. **Within scope**, the agent splits and commits silently — that is the checkpoint behavior. **Outside scope**, it stops and asks: "there's an unrelated change in `movement/movement.sh`; commit it separately, or leave it dirty?"

That prompt only fires when there is genuinely stray work, so it is rare. It is also exactly the moment where the agent's scope judgment could be wrong in a way the user would care about.

### Outside a spike, confirm first
`commit-work` is invocable directly, not only through `run-project-spike`. With no spike context there is no blessed boundary and no slug, so it drafts the message, shows it, and commits on a conversational yes. It writes no `Spike:` trailer. Confirmation here is not ceremony — it is the substitute for the approval that the spike's completion boundary would otherwise have supplied.

When invoked directly *while* a spike is active and more than one spike could claim the work, it asks which. A missing trailer is trivially fixable before push; a wrong one silently poisons the query.

### Most commits have no body
The standard advice is "explain *why*, not *what*." It assumes commits large enough to have a why. But `run-project-spike` items are atomic by design, so the modal commit here is something like `movement: increase bullet indent` — and the subject exhausts it.

An agent given a field labelled "body" and told to explain *why* will produce a why for that commit too. It will write something nobody thought, that is not the reason, and that is now permanently indistinguishable from a real explanation. **Confabulated rationale is worse than an empty body**, and it corrupts precisely the archaeological record this spike exists to create.

So the default inverts: subject-only, unless there is a why the subject and the diff do not already carry. And in a spike, the `.todo.md` edit ships in the same commit, so the intent is frequently *already in the diff* — a body would restate a file the commit contains.

Bodies are **not** hard-wrapped. `AGENTS.md`'s rule applies here unchanged, with no exception.

This was argued the other way first and lost, which is worth recording. The case for wrapping at 72: git prefixes every literal line of a body (four spaces under `git log`, graph characters under `--graph`), and a terminal soft-wrapping a long line starts the continuation at column zero, outside the prefix, so the paragraph's left edge collapses. That was demonstrated, and it is true.

It is also merely cosmetic. Nothing is lost or truncated. Meanwhile a body wrapped at 72 is correct at exactly one width and wrong at every other — double-wrapped into a long/short alternation in a narrow terminal, short-lined in a wide forge column. These commits will mostly be read on a code forge, not in `git log`.

And the repo's rule was never really about Markdown. It is the principle that **formatting is the client's job, not the content's**, and plain text consumed by many clients at many widths is the case that principle exists for. Carving an exception because `git log`'s indent looks untidy would leave `AGENTS.md` with a rule and an asterisk.

What survives is the part git actually parses, which is not formatting: a blank line separates subject from body, and trailers are the final paragraph with no blank lines between them. Break either and `git log --format='%(trailers:key=Spike)'` stops working.

### The archival commit is a synthesis
Archiving a spike is itself a commit: both docs move from `docs/active-spikes/` to `docs/archive/`, and `TODO.md` updates. That commit's diff *is* the archival, so its message is the spike summary — and it is the one message the user reviews before it lands.

That message is **not** a rollup of the intermediate commits. It draws on the trailer log (`git log --grep='Spike: <slug>'`), the conceptual doc, the to-do doc's `Done` section, and the agent's working context at close time. The most valuable content is precisely what cannot be derived from the diff: what was tried and abandoned, what turned out to be the wrong frame, which constraint was discovered halfway through. **Dead ends leave no trace in the tree.** If they are not written at close, they are gone.

The summary message and the archival doc pass are the same act, written from the same synthesis.

## Rejected Alternatives
- **`git add` of named paths, then commit.** Safer than `gitall`, still unsafe: it touches the shared index. Pathspec commit is strictly better and simpler.
- **`GIT_INDEX_FILE` per agent.** Correct, but machinery for a problem not yet observed. Held as an escape hatch.
- **Branch per spike, merged at archival.** Maps onto git's grain but is far heavier than a dotfiles repo warrants, and the user is deliberately building git habits from a low base.
- **Making `gitall` refuse to run when `docs/active-spikes/` is non-empty.** Considered and declined. `gitall` stays as it is and falls out of use naturally.
- **`git commit -e -F <file>` for review.** Rejected as too much ceremony. Approval, where needed, is a conversational yes.

## Writing The Skill Itself
`commit-work` is a **discipline skill**: most of its content is rules an agent must not talk itself out of, under pressure, mid-task. That is a different authoring problem from `run-project-spike`, which mostly teaches taste.

Borrowed from the Superpowers `writing-skills` guidance (https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md), two techniques apply here and should shape `skills/commit-work/SKILL.md`:

**Close the loopholes by name.** A rule stated once will be reasoned around. State the rule, then enumerate the specific rationalizations and refuse each one. The table lives in `skills/commit-work/SKILL.md` and is authoritative there; it is not duplicated here, because two copies would drift. Grow it whenever a new excuse is caught in the wild.

The rows worth knowing about, because they were not obvious in advance: git's own refusal to `git add` an ignored file *recommends the `-f` flag that would commit the secret*, and an agent reads tool output as instruction. And an agent handed a field labelled "body" will fill it, inventing a rationale for a change that had none.

**Put violation symptoms in the `description:` field.** The description is what an agent reads when deciding whether to load the skill, so it should contain the words an agent is thinking at the moment it is about to do the wrong thing: `git add`, `gitall`, `push`, `amend`, `commit -a`.

Explicitly *not* adopted from that document: its Iron Law that no skill may be written without a failing test first, and its RED/GREEN/REFACTOR cycle for skill authoring. These skills are prose, reviewed by a human who is building the taste they encode; a test harness would substitute for the involvement that is the point. What survives the rejection is the kernel underneath — *know what an agent does without the rule before writing the rule*. This repo already has that evidence, gathered in the wild: see the incident recorded in `docs/active-spikes/skill-authority.md`.

## Relationship To Other Spikes
Born from the same design conversation as `docs/active-spikes/skill-authority.md`, but the subjects do not overlap: one is about git, the other about which copy of a skill is authoritative. They are siblings, not phases, so no continuation markers.

`commit-work` should be built **first**, then used to commit the `skill-authority` work. That is a real dogfooding test — `skill-authority` is small enough that if the commit workflow is annoying, it will be felt immediately and cheaply.

## Durable Output
The commit policy — *agent commits, never pushes; always pathspec; commit at completion, not at Done* — constrains every future agent in this repo. It belongs in `docs/decisions/0003-agent-commit-policy.md`, not buried in a spike doc that eventually archives.

The Claude memory currently records "git commits are user-handled; don't commit or offer to." That memory will actively fight this design in every future session and must be rewritten once the decision record lands.

`AGENTS.md` gets a pointer to 0003. An agent that never opens `docs/decisions/` should still learn, from the file it always reads, that it may commit and must not push.

## Deferred
Whether agents need an interface for coordinating when two of them must genuinely touch the same file is pinned in `docs/deferred-decisions.md`. The pathspec rule makes concurrent *commits* safe; it does nothing about two agents editing the same file in the working tree. That hazard is real but unobserved, and out of scope here.
