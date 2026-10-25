---
name: lifeos-resume
description: "Use the legacy lifeos resume render entrypoint to export a Markdown resume to PDF. Delegates rendering and themes to render-markdown-pdf while preserving the existing output and theme defaults."
---

# Legacy Resume Render
Rendering mechanics, setup, asset restrictions, and visual verification now belong to [render-markdown-pdf](../../../agent-hands/skills/render-markdown-pdf/SKILL.md). Source selection, résumé content, and destination conventions remain with the calling private workflow. This compatibility entry does not grant publication permission.

```sh
lifeos resume render resume.md --output exports/resume.pdf
```

The wrapper defaults to the bundled résumé theme and `<source-name>.pdf` beside the input. It creates the requested output directory and preserves the existing overwrite behavior by passing `--force`; failed rendering leaves the previous PDF untouched. `--theme CSS` still accepts an explicit stylesheet; the previous `lib/resume-theme/` paths remain compatibility links. `--open` opens a successful result using macOS `open` when available.

Use repeatable `--asset-dir DIR` for a dedicated local image/style/font directory when necessary. Remote resources are refused, and PDF attachments/local-file hyperlinks are omitted. Relative images and CSS imports now resolve against their actual source locations. The bundled compact theme retains the prior letter/compact margins. Do not grant a directory containing private unrelated files.

Dependencies are now Pandoc, native Pango/fonts, and the renderer's own locked uv environment. The global `weasyprint` executable is no longer used by this entry. See the owning skill for setup and platform limits. No credentials are needed by the renderer.
