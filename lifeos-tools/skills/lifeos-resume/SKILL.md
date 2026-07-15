---
name: lifeos-resume
description: "Use when rendering a Markdown resume to a themed PDF through the lifeos CLI (`lifeos resume render`): the command and options, the pandoc + WeasyPrint pipeline (YAML frontmatter is stripped automatically), dependencies and setup, and where the theme lives."
---

# LifeOS Resume Render
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-resume/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material. See `lifeos-cli` for the shared rules.

This skill covers the render **mechanics** only. Vault-side conventions — which resume is canonical, where PDFs belong, references handling, the frontmatter schema — live in the LifeOS vault skill `resume-management`.

## Command
```sh
lifeos resume render INPUT.md [--output PATH] [--theme CSS] [--open]
```
- `INPUT.md` — the Markdown resume source (source of truth).
- `--output PATH` — output PDF. Default: `<name>.pdf` next to the source.
- `--theme CSS` — override the theme CSS. Default: the vendored `lib/resume-theme/aslan-resume.css`.
- `--open` — open the PDF after rendering (macOS `open`).

```sh
lifeos resume render aslan-french-resume.md --output public-resumes/aslan-french-resume.pdf
```

## Pipeline
Markdown → PDF, no app in the loop:
1. Strips a leading YAML frontmatter block, so resume metadata never reaches the PDF.
2. `pandoc` converts Markdown → HTML (inline HTML like `<span class="date">` passes through).
3. Wraps the HTML in Typora's `#write` container + the theme CSS, so element rules and `#write`-scoped rules both apply.
4. `weasyprint` renders HTML → PDF (letter, 0.7" margins per the theme's `@page`).

Fonts resolve from installed system fonts (Merriweather headings, Arial body) — no network.

## Markdown conventions the theme expects
- Name = `#` (H1); contact line = `######` (H6, right-aligned).
- Section title = `##`; role = `###`; company + date = `####` with the date in `<span class="date">…</span>` (a flex rule pushes it right).
- Bullets = `-` lists.

## Dependencies & setup
- `pandoc` and `weasyprint` — system tools, installed via the configs installer (`brew-installs.sh` on mac, `dnf-installs.sh` on Fedora). `weasyprint` needs native libs (pango/cairo) that brew bundles; it is deliberately a system dep, not a Python package.
- Theme vendored at `lib/resume-theme/aslan-resume.css` (source: https://github.com/jcklpe/typora-resume-theme). Re-copy it there when the upstream theme changes.
- `lifeos doctor` reports whether pandoc + weasyprint are present.

## Notes
- Pure renderer: it does not decide which resume to render or where PDFs belong — that is the vault skill's job.
- Re-run after any source edit; the PDF is a regenerable artifact.
- Failures print WeasyPrint's stderr; a common cause is a missing dep (run `lifeos doctor`).
