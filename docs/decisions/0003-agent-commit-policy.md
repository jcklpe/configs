# 0003 Agent Commit Policy
## Context
This repo's git history has been produced by `gitall`: a sweep-everything-into-one-commit-and-push helper. It works for a solo dev who never reads their own history back. It fails at three things now wanted from it — collaborating with other humans, supporting future archaeology, and generating source material for written case studies about how work actually went.

Until now the standing rule was that agents never commit. That rule existed because an agent committing with `git commit -a` is indistinguishable from `gitall`, only faster and less accountable. The rule was protecting against bad commit *scope*, not against agents.

Two things changed. `run-project-spike` produces naturally atomic units of work with their reasoning already written down, which is most of a good commit. And the user routinely runs two agents at once in the same clone, which makes commit safety a correctness question rather than a stylistic one: git's index is repo-global shared mutable state, so one agent's `git add` followed by another's bare `git commit` silently places the first agent's files in the second's commit, under the wrong message.

## Decision
Agents may commit in this repo. Agents may never push.

The line is drawn at **reversibility, not importance**. An unpushed local commit costs nothing to undo, so it needs no approval. A push is irreversible in practice, because someone may have pulled it. The whole unpushed window is the review window.

Concretely:

- **Commit by pathspec. Never stage.** `git commit -F - -- <explicit paths>`. Never `git add` a path about to be committed, never `git commit -a`, never a bare `git commit`. This is what makes concurrent agents safe, and the safety is a property of the command rather than of timing.
- **Never `git add -f`.** Git's refusal to add a `.gitignore`d file prints `hint: Use -f if you really want to add them`, and `-f` then stages it silently. Run `git check-ignore -q <path>` before any `git add`. See [0001](0001-secrets-and-local-env.md).
- **Never rewrite history.** No `--amend`, no rebase, no `--force`, no `--no-verify`. Another agent may have built on the commit.
- **Never push.** No exception for "obviously ready."
- **Commit at the completion boundary**, when implementation is finished and verified as far as the terminal allows — not when a human moves the item to `Done`, which is bookkeeping and may happen days later or never.
- **One commit does one thing.** If an honest one-line summary needs the word "and," it is two commits.
- **Inside a spike's file scope, commit silently. Outside it, ask.**
- Spike commits carry a `Spike: <slug>` trailer, a bare slug rather than a path, because paths change when a spike archives and commit messages do not.

`skills/commit-work/SKILL.md` is the operational skill and holds the failure-mode table, the rationalization table, and the message format. This record holds the rule.

## Consequences
Commit scope stops being an accident of when someone got around to running `gitall`, which is the precondition for every other benefit. Message quality follows from scope; it cannot precede it.

`git log --grep='Spike: <slug>$' --reverse` reconstructs any spike's history in order, and the archival commit's message is a synthesis of it. Together these make the commit log a durable, greppable index into the spike docs, in the same way that `🔗 Continues in:` markers index Trello cards to one another.

`gitall` and `gitcommit` are not deprecated, guarded, or changed. They stay for casual work. They are, however, the commands that can sweep an agent's in-progress work into an unrelated commit, because each is `git add -A` followed by a bare commit over the shared index. **Do not run `gitall` or `gitcommit` in a repo where an agent is working.** Verified: an agent's untracked scratch file lands inside the resulting commit, silently.

`gitpush` is safe to run at any time. It touches no index, and it is the human-only step this record turns on.

The main risk is silent bad scope: an agent committing without confirmation could quietly produce an incoherent history. Mitigations are that commits are unpushed and cheap to undo, that the pathspec rule forces the agent to name every file it commits, and that stray work outside a spike's scope triggers a question rather than a commit.

This record supersedes the previous "agents never commit" rule, including any stored agent memory that still asserts it.

## Links
- [AGENTS.md](../../AGENTS.md)
- [0001 Secrets And Local Env Hygiene](0001-secrets-and-local-env.md)
- [skills/commit-work/SKILL.md](../../skills/commit-work/SKILL.md)
- [skills/run-project-spike/SKILL.md](../../skills/run-project-spike/SKILL.md)
- [Commit Work spike](../active-spikes/commit-work.md)
