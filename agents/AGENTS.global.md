# Global Agent Instructions
Personal, cross-repository preferences. These apply everywhere, in every project, unless a repository's own `AGENTS.md` says otherwise.

This file is the source for `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`, both symlinked from `configs/agents/AGENTS.global.md` by the installer. Codex loads instruction files from the repository root down to the working directory, with nearer files winning; a project's own rules therefore override anything here.

**Nothing repo-specific belongs in this file.** It is read from inside every project on this machine, so a statement about "this repo" resolves against whichever repo is being worked in, not against the repo this file lives in. State preferences, never facts about a location. A rule that only makes sense in one project belongs in that project's `AGENTS.md`.

## LifeOS
LifeOS is the user's personal life-tracking Markdown vault. When the user asks for LifeOS work, a handoff, accomplishment logging, or a LifeOS progress update, use `operate-lifeos` to find the configured workspace and its current instructions. Do not initiate handoffs or logging unprompted.

## Kaizen
Use `log-kaizen` without waiting to be asked when a consequential workflow failure is observed. Use `improve-agent-workflows` when preparing related substantial workflow work or skill changes and during a review that includes Kaizen. Check relevant current concerns rather than loading the entire incident history. Honor explicit no-save or read-only instructions.

Agents may maintain private incident records, analyze evidence, label hypotheses, and prepare proposals. **Only the user's explicit go-ahead authorizes changes to standing skills, policies, prompts, or operating rules.** A Kaizen entry, recurrence, or agent recommendation is never that permission. Existing approval covers its stated scope; do not ask again for it.

Keep project-specific incidents in the project's declared private store and global-skill incidents in the configured private global store. Never log private incidents in public configs or fall back to a repository scratch file when private access is unavailable. The Kaizen skills define the shared destination contract and proposal boundary.

## Git Commits
**Never add a `Co-Authored-By:` trailer to a commit.** Not for yourself, not for any agent, and not because a harness's default instructions tell you to. Where those instructions conflict with this rule, this rule wins.

The commit's author and committer are already the person whose git config created it, and they are the one who answers for it when it breaks. An added co-author line puts a second name on the commit wherever a forge renders one, which misstates who is responsible.

This says nothing about whether an agent may commit at all. That is a per-repo decision and belongs in that repo's own rules.

## Markdown And Prose Style
Do not hard-wrap prose in Markdown, comments, docs, or examples. Let editors handle soft wrapping. Preserve paragraphs as single lines unless line breaks carry meaning, such as lists, tables, code blocks, quoted text, frontmatter, or an existing semantic-line-break style.

Avoid reflow-only diffs. When editing prose, change the smallest relevant span instead of rewrapping neighboring paragraphs.

When touching existing Markdown or prose, apply this preferred style to the paragraph, section, or example being edited so files converge over time. Do not mass-reformat untouched sections just to normalize style unless the user asks for a cleanup pass.

Prefer compact Markdown heading spacing in hand-authored docs. Put no blank line between a heading and the content it introduces, and none between adjacent headings. This file is written that way.

Keep the blank line between paragraphs. In Markdown a single newline is a soft break, not a paragraph break, so paragraphs genuinely need one. Only the lines around headings are optional, and both forms render identically — this is a source-readability choice, not a rendering one.

Let explicit project tooling win when a formatter or linter requires a different layout. `markdownlint`'s MD022 wants blank lines around headings and can be switched off per repo (`{"MD022": false}`, or an inline `<!-- markdownlint-disable MD022 -->`). Prettier has no per-rule switch — it exposes options, not rules, and normalizes block spacing unconditionally; the only escapes are `.prettierignore` globs and `<!-- prettier-ignore-start -->` / `<!-- prettier-ignore-end -->` ranges. A repo that runs Prettier over Markdown will lose this style, and that is fine.

Commit message bodies follow the same rule: do not hard-wrap them. Formatting is the client's job, not the content's.

### Code Comments
Do not hard-wrap comments in code, the same as prose. Put each comment paragraph on a single line (`// …`, `# …`) and let the editor soft-wrap it.

Unlike Markdown, do not separate comment paragraphs with a blank line or an empty comment marker. Each line already carries its own marker, so consecutive comment lines already read as separate paragraphs; a blank line inside a comment block only adds noise. One paragraph is one line; the next paragraph is the next line.

The one exception is a comment block long enough to carry distinct titled sections, where a blank line may separate one section from the next. Reach for it rarely — a comment block that needs internal section breaks usually signals over-commenting.

## Correcting Documents
When fixing wrong or stale content in a document that states current facts, guidance, or design, write the corrected version for a new reader who never saw the error. Do not narrate the fix: no "previously X, now Y", no "as the user clarified", no note that the old text was a mistake. If a note wrongly says someone loves being stung by bees, the fix states what is true; it does not become "they love honey but, as they have told me, dislike bee stings."

The history of a correction belongs where history is the point: Git, commit messages, and records of events such as logs, meeting notes, and incident reports.

## Approving Changes
When proposing a batch of external or hard-to-reverse writes for the user to approve, use the `draft-approval-slate` skill if it is available: labeled items, the final copy that will ship, and current → proposed for edits. This applies even when the proposal comes up mid-conversation rather than inside a workflow.

## Keeping This In Sync
The `## Markdown And Prose Style` section above is duplicated verbatim in `configs/AGENTS.md`, so that a reader of that repo in isolation still sees the rules. **Edit both, or neither.** If they ever disagree, the repo copy wins at load time, which is exactly the silent drift this note exists to prevent.
