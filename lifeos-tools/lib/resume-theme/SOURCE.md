# Vendored resume theme

`aslan-resume.css` is a vendored copy of the Typora resume theme:
https://github.com/jcklpe/typora-resume-theme

It is used by `lifeos resume render` to reproduce the Typora look in a headless
(app-free) Markdown → PDF pipeline. When the upstream theme changes, re-copy
`aslan-resume.css` here. The same file can stay installed in Typora for
interactive editing/preview; this copy keeps the CLI render self-contained.
