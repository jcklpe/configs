---
name: track-changes
description: "Review Markdown documents by inserting inline CriticMarkup annotations: comments (`{author=\"Name\">>...<<}`), additions (`{author=\"Name\"++...++}`), deletions (`{author=\"Name\"--...--}`), substitutions (`{author=\"Name\"~~old~>new~~}`), and highlights (`{author=\"Name\"==...==}`). Use when the user asks to review, critique, comment on, or annotate a note or essay; says \"add inline comments\", \"use track changes\", or asks to process replies to prior review comments. Do not use for writing new prose, rephrasing, or rewriting; this skill is review-only and never modifies human-authored text outside of CriticMarkup wrappers."
---

# Track Changes
## Local Precedence
If the current repo already has `skills/track-changes/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## Reviewer Mode
You review markdown documents by adding inline CriticMarkup annotations. You never write or rewrite the prose itself. Be a critical, analytical reader.

This skill adapts the Obsidian Track Changes plugin's reviewer workflow and metadata-prefixed CriticMarkup syntax.

## Hard Rules
- **Never rewrite, rephrase, or generate text.** Human-authored text stays human-authored; you only wrap it in CriticMarkup.
- **Don't change tone, style, or voice.** Respect the author's choices, even unconventional ones.
- Only flag clear problems. Don't nitpick stylistic preferences.
- Don't guess. If you're unsure about a fact, quote, or attribution, look it up.

## How To Insert Annotations
By default, insert findings directly into the document as inline CriticMarkup. **Switch to chat-only mode** with a numbered list and no edits only when explicitly told, such as "just list them", "summarize in chat", or similar.

Five forms, always carrying your `author="..."` prefix:

- `{author="Codex">>text<<}` — comment (your default)
- `{author="Codex"++text++}` — propose adding
- `{author="Codex"--text--}` — propose deleting
- `{author="Codex"~~old~>new~~}` — propose replacing
- `{author="Codex"==text==}` — highlight: draw attention, no proposal

Guidance:

- Place the annotation immediately after the passage it refers to, in the same paragraph if it fits, otherwise on the next line.
- Do not insert a blank line between the passage and annotation, or threading breaks.
- Don't modify the surrounding text. Insert markup only.
- **Comments are the default.** Use `++`, `--`, and `~~` only for short, obvious fixes. Anything that warrants explanation goes in a comment.
- Use `==` sparingly, only when you can't form a useful comment. A bare suggestion or highlight without rationale is noise.
- To point a comment at an exact span, put a highlight **directly** before it: `{==the span==}{author="Codex">>why<<}`, with nothing between them but spaces. The panel folds the pair into a single card that quotes the span, so the anchoring costs the user no extra review entry. Any gap, such as prose or a newline, splits them back into two cards.
- To give a suggestion its rationale, put the comment **directly** after it: `{author="Codex"~~old~>new~~}{author="Codex">>why<<}`. The panel shows the comment inside the suggestion's card, and accepting or rejecting the suggestion **deletes the comment with it**. So don't put anything the user must keep there; anything meant to outlive the decision goes in a separate comment after some prose or on its own line.

### AI-Added Text (`{=+ ... +=}`) Is Not A Review Mark
A sixth mark, `{author="Codex"=+inserted text+=}`, flags prose **you inserted** into the document. It renders as a subtle rainbow highlight, has no review card, and is never accepted or rejected; the user edits it in or strips it at publish.

It exists for a co-writing or drafting mode and is **outside strict review**. Don't emit it while reviewing; the hard rules above still forbid generating prose. Only use it when the user explicitly asks you to draft or insert inline text. The `author=` and `date=` prefix works on it exactly like the other marks.

## Attribution Prefix
Put `author="<your model name>"` on **every** mark you create, and keep one name (`Codex`, `Claude`, `GPT`, `Gemini`, etc.) throughout a document.

The prefix is one or more `key="value"` pairs placed **between the outer `{` and the sigil** (`++`, `--`, `~~`, `>>`, `==`, `=+`):

- values are **double-quoted**
- pairs are **space-separated**
- keys are **lowercase**
- there is **no leading whitespace** after the `{`
- the closing quote of the last pair **abuts the sigil**
- a value **may not contain `"`, `{`, `}`, or a newline**; everything else, such as spaces, `;`, `=`, `:`, `-`, `.`, `,`, and `'`, is fine
- an unclosed quote, such as `{author="Codex++x++}`, doesn't parse and is left as literal text
- the prefix works **uniformly on all six marks**

```md
{author="Codex" date="2026-06-14"++added text++}
{author="Codex"~~old~>new~~}
{author="Codex">>a comment<<}
```

Recognized keys:

- **`author`** — your model name. Set it on every mark.
- **`date`** — `YYYY-MM-DD` or `YYYY-MM-DDThh:mm:ssZ`. Optional and display-only. You usually don't know the real date, so omit it rather than guess. If you do emit a time, prefer `Z` over a numeric offset such as `+02:00`.

The prefix sits **outside** the payload delimiters, so accept, reject, and finalize strip it automatically and it never leaks into published output. Never put attribution inside the payload: not `{++Codex: text++}`, not `{>>Codex: text<<}`. It belongs in the prefix.

## Replies And Threads
Effective author resolves: `author="..."` -> host's configured local-author name -> `You`.

Adjacent `{>>...<<}` blocks with no blank line between them, in the same paragraph, form one thread. The prefix lives outside the `>>` and `<<` delimiters, so it doesn't affect threading. A `{==...==}` highlight or a `++`, `--`, or `~~` suggestion directly before the root is the thread's **anchor**, not a thread member; replies still attach after the last comment.

**The user's replies are written by the plugin**, which stamps the date and, if the user configured a name, their `author="..."`. Treat any reply with **no `author=`**, or one carrying the user's configured name, as the **user's**, not yours. Never stamp the user's name or invent dates yourself.

When asked to "process replies" or "address my comments", make a pass and act only on threads the user has actually replied to. A comment with no reply is still waiting on them; leave it alone. A thread on a suggestion the user replied to counts like any other.

- `{>>ignore<<}` / `{>>won't fix<<}` -> leave the thread in place; it documents the decision.
- `{>>done<<}` -> verify the surrounding text actually addresses your comment. If yes, delete the whole thread. If not, push back with a new `{author="Codex">>follow-up<<}` adjacent to the thread.
- `{>>expand<<}` or any question -> add an adjacent `{author="Codex">>answer<<}`.
- Counter-argument -> engage: concede by deleting the thread or push back with a new adjacent comment. If you concede on a thread anchored on your suggestion, withdraw the suggestion too: restore `old` for `~~old~>new~~` or `x` for `--x--`, and drop `++x++`.

Aim to converge toward only the resolved-but-kept (`ignore`) threads remaining.

## Human-Authored Marks
The host plugin lets the user create any of the five reviewable marks themselves, straight from the editor, in the same `{author="..." date="...">>...<<}` shapes you produce. **Don't assume every non-comment mark is yours.** Check `author=` before treating a mark as your own proposal to revisit; a mark with no `author=`, or with the user's configured name, is the user's, exactly like a reply with no author.

## What Good Reviewer Output Looks Like
- Quote or refer to the specific passage.
- State the issue plainly.
- Suggest a *direction*, not a rewrite.
- If the note looks fine, say so briefly. No empty praise.

## Source Note
This skill adapts the CriticMarkup reviewer workflow from the MIT-licensed Obsidian Track Changes project: https://github.com/philphilphil/obsidian-track-changes/blob/main/docs/SKILL.md

Last synced with upstream commit `9d7a799` (2026-09-23, plugin 2.2.0).
