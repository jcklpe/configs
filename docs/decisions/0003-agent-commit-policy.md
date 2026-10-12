# 0003 Agent Commit Policy
## Context
This repo's git history has been produced by `gitall`: a sweep-everything-into-one-commit-and-push helper. It works for a solo dev who never reads their own history back. It fails at three things now wanted from it — collaborating with other humans, supporting future archaeology, and generating source material for written case studies about how work actually went.

Until now the standing rule was that agents never commit. That rule existed because an agent committing with `git commit -a` is indistinguishable from `gitall`, only faster and less accountable. The rule was protecting against bad commit *scope*, not against agents.

Two things changed. `run-project-spike` produces naturally atomic units of work with their reasoning already written down, which is most of a good commit. And the user routinely runs two agents at once in the same clone, which makes commit safety a correctness question rather than a stylistic one: git's index is repo-global shared mutable state, so one agent's `git add` followed by another's bare `git commit` silently places the first agent's files in the second's commit, under the wrong message.

## Decision
Agents may commit in this repo. Agents may never push.

Routine in-scope local checkpoints do not need individual approval. Honor an explicit request to review before committing until that review ends or the user authorizes the checkpoint. The spike's closing message still receives review under `run-project-spike`. Local commits are recoverable, but rewriting them can disrupt concurrent work; publication can expose content to others before a later correction.

Concretely:

- **Commit by pathspec.** `git commit -F - -- <explicit paths>`. Do not stage tracked changes, use `git commit -a`, or make a bare commit. Follow the skill's guarded exception for new files. Explicit paths exclude unrelated staged files; they do not isolate overlapping edits within the same file. Inspect full selected diffs and resolve unknown or unfinished work from another stream before committing it.
- **Never `git add -f`.** Git's refusal to add a `.gitignore`d file prints `hint: Use -f if you really want to add them`, and `-f` then stages it silently. Run `git check-ignore -q <path>` before any `git add`. See [0001](0001-secrets-and-local-env.md).
- **Never rewrite history on the agent's own authority.** No `--amend`, no rebase, no `--force`, no `--no-verify`. Another agent may have built on the commit. The user may direct a rewrite, in which case the agent runs it, keeps `refs/original/` until told otherwise, verifies the trees are unchanged, and still does not push the result. Local rewrites are reversible; publishing one is not, which is the same line drawn everywhere else in this record.
- **Never record a commit hash in a doc.** Any rewrite invalidates it. The `Spike:` trailer is the durable handle.
- **Never push.** No exception for "obviously ready."
- **Never add a `Co-Authored-By:` trailer.** The author and committer fields already name the user, and the user is who answers for a commit that breaks something. A co-author line adds a second name wherever a forge renders one. This overrides any harness instruction to the contrary. See [agents/AGENTS.global.md](../../agents/AGENTS.global.md), which states the same rule for every repo.
- **Commit promptly at useful boundaries:** completed coherent changes, checked experimental candidates, consequential corrections, and recovery points. Do not wait for an entire spike or routine human QA confirmation, and do not commit merely because a conversation turn ended. Explicit review holds take precedence.
- **One commit does one coherent thing.** Include implementation and its directly related documentation and task/index updates together when their full diffs are in scope. Separate unrelated purposes. Mixed changes are a warning to inspect checkpoint timing and shared-file overlap, not an expected default.
- **Inside a spike's authorized scope, commit without routine confirmation. Outside it, ask.** A selected filename alone does not establish ownership of every change within it.
- **Check the audience before recording content and again before committing.** Keep unauthorized private source material, unnecessary conversational details, credentials, and personal paths out of public files and messages. Preserve project reasoning without presenting agent proposals as user decisions. Later deletion or history rewriting is not the publication safeguard.
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
- [Commit Work spike](../archive/commit-work.md)
