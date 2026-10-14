# 0003 Agent Commit Policy
## Current Approach
Agents may commit in this repo. Agents may never push.

Routine in-scope local checkpoints do not need individual approval. Honor an explicit request to review before committing until that review ends or the user authorizes the checkpoint. Under `run-project-spike`, establish authorization to close before marking or moving the pair into history; one clear approval can cover closure and its closing message, but wording-only approval is not closure. Local commits are recoverable, but rewriting them can disrupt concurrent work; publication can expose content to others before a later correction.

Concretely:

- **Commit by pathspec.** `git commit -F - -- <explicit paths>`. Do not stage tracked changes, use `git commit -a`, or make a bare commit. Follow the skill's guarded exception for new files. Explicit paths exclude unrelated staged files; they do not isolate overlapping edits within the same file. Inspect full selected diffs and resolve unknown or unfinished work from another stream before committing it.
- **Never `git add -f`.** Git's refusal to add a `.gitignore`d file prints `hint: Use -f if you really want to add them`, and `-f` then stages it silently. Run `git check-ignore -q <path>` before any `git add`. See [0001](0001-secrets-and-local-env.md).
- **Never rewrite history on the agent's own authority.** No self-directed `--amend`, rebase, or `--force`; never use `--no-verify`. For a user-directed rewrite, establish the intended branch, range, and result; check for concurrent work or others relying on that history; create and verify a unique recovery reference before starting. Preserve any uncommitted inputs separately if the operation could disturb them. Keep the recovery ref until told otherwise. Verify identical final contents for a message-only rewrite or squash preserving the final state; when the request includes reviewed content changes, verify exactly those differences and preserve unrelated content. Check the intended sequence and messages as well. Do not push the result; local recovery cannot retract already distributed copies. See `commit-work` for mechanics.
- **Never record a commit hash in a doc.** A rewrite can replace the referenced commit. The `Spike:` trailer is the durable handle.
- **Never push.** No exception for "obviously ready."
- **Never add a `Co-Authored-By:` trailer.** The author and committer fields already name the user, and the user is who answers for a commit that breaks something. A co-author line adds a second name wherever a forge renders one. This overrides any harness instruction to the contrary. See [agents/AGENTS.global.md](../../agents/AGENTS.global.md), which states the same rule for every repo.
- **Commit promptly at useful boundaries:** completed coherent changes, checked experimental candidates, consequential corrections, and recovery points. Do not wait for an entire spike or routine human QA confirmation, and do not commit merely because a conversation turn ended. Explicit review holds take precedence.
- **One commit does one coherent thing.** Include implementation and its directly related documentation and task/index updates together when their full diffs are in scope. Separate unrelated purposes. Mixed changes are a warning to inspect checkpoint timing and shared-file overlap, not an expected default.
- **Inside a spike's authorized scope, commit without routine confirmation. Leave unrelated dirty paths untouched and continue.** Ask when overlapping edits, dependencies, or uncertain ownership prevent a safe checkpoint, or before expanding into unauthorized work. A selected filename alone does not establish ownership of every change within it.
- **Check the audience before recording content and again before committing.** Keep unauthorized private source material, unnecessary conversational details, credentials, and personal paths out of public files and messages. Preserve project reasoning without presenting agent proposals as user decisions. Later deletion or history rewriting is not the publication safeguard.
- Spike commits carry a `Spike: <slug>` trailer, a bare slug rather than a path, because paths change when a spike archives and commit messages do not.

`skills/commit-work/SKILL.md` is the operational skill and holds the failure-mode table, the rationalization table, and the message format. This policy holds the rule.

## Rationale
Local commits are recoverable checkpoints; pushes publish content and are reserved for the user. Concurrent agents share one Git index, so explicit path selection, full-diff review, timely checkpoints, and overlap resolution prevent unrelated work from entering the wrong commit. Coherent scope makes history usable for later reconstruction and case-study source material.

## Operating Notes
Commit scope stops being an accident of when someone got around to running `gitall`, which is the precondition for every other benefit. Message quality follows from scope; it cannot precede it.

`git log --grep='Spike: <slug>$' --reverse` reconstructs any spike's history in order, and the archival commit's message is a synthesis of it. Together these make the commit log a durable, greppable index into the spike docs, in the same way that `🔗 Continues in:` markers index Trello cards to one another.

`gitall` and `gitcommit` are not deprecated, guarded, or changed. They stay for casual work. They are, however, the commands that can sweep an agent's in-progress work into an unrelated commit, because each is `git add -A` followed by a bare commit over the shared index. **Do not run `gitall` or `gitcommit` in a repo where an agent is working.** Verified: an agent's untracked scratch file lands inside the resulting commit, silently.

`gitpush` is safe to run at any time. It touches no index, and it is the human-only step this record turns on.

The main risk is silent bad scope: an agent committing without confirmation could quietly produce an incoherent history. Mitigations are recoverable local checkpoints, explicit path selection, full-diff inspection, and resolving overlap before committing. Unrelated work outside the selected paths remains untouched; its presence alone does not require a question.

## Links
- [AGENTS.md](../../AGENTS.md)
- [0001 Secrets And Local Env Hygiene](0001-secrets-and-local-env.md)
- [skills/commit-work/SKILL.md](../../skills/commit-work/SKILL.md)
- [skills/run-project-spike/SKILL.md](../../skills/run-project-spike/SKILL.md)
- [Commit Work spike](../archive/commit-work.md)
