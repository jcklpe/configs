# Global Agent Instructions
Personal, cross-repository preferences. These apply everywhere, in every project, unless a repository's own `AGENTS.md` says otherwise.

This file is the source for `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`, both symlinked from `configs/agents/AGENTS.global.md` by the installer. Codex loads instruction files from the repository root down to the working directory, with nearer files winning; a project's own rules therefore override anything here.

**Nothing repo-specific belongs in this file.** It is read from inside every project on this machine, so a statement about "this repo" resolves against whichever repo is being worked in, not against the repo this file lives in. State preferences, never facts about a location. A rule that only makes sense in one project belongs in that project's `AGENTS.md`.

## Markdown And Prose Style
Do not hard-wrap prose in Markdown, comments, docs, or examples. Let editors handle soft wrapping. Preserve paragraphs as single lines unless line breaks carry meaning, such as lists, tables, code blocks, quoted text, frontmatter, or an existing semantic-line-break style.

Avoid reflow-only diffs. When editing prose, change the smallest relevant span instead of rewrapping neighboring paragraphs.

When touching existing Markdown or prose, apply this preferred style to the paragraph, section, or example being edited so files converge over time. Do not mass-reformat untouched sections just to normalize style unless the user asks for a cleanup pass.

Prefer compact Markdown heading spacing in hand-authored docs. Put no blank line between a heading and the content it introduces, and none between adjacent headings. This file is written that way.

Keep the blank line between paragraphs. In Markdown a single newline is a soft break, not a paragraph break, so paragraphs genuinely need one. Only the lines around headings are optional, and both forms render identically — this is a source-readability choice, not a rendering one.

Let explicit project tooling win when a formatter or linter requires a different layout. `markdownlint`'s MD022 wants blank lines around headings and can be switched off per repo (`{"MD022": false}`, or an inline `<!-- markdownlint-disable MD022 -->`). Prettier has no per-rule switch — it exposes options, not rules, and normalizes block spacing unconditionally; the only escapes are `.prettierignore` globs and `<!-- prettier-ignore-start -->` / `<!-- prettier-ignore-end -->` ranges. A repo that runs Prettier over Markdown will lose this style, and that is fine.

Commit message bodies follow the same rule: do not hard-wrap them. Formatting is the client's job, not the content's.

## Keeping This In Sync
The `## Markdown And Prose Style` section above is duplicated verbatim in `configs/AGENTS.md`, so that a reader of that repo in isolation still sees the rules. **Edit both, or neither.** If they ever disagree, the repo copy wins at load time, which is exactly the silent drift this note exists to prevent.
