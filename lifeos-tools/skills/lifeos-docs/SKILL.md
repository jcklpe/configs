---
name: lifeos-docs
description: "Use the legacy lifeos docs command for an existing Google Doc while routing its mechanics to the portable use-google-docs skill."
---

# Legacy Google Docs Route
Read [use-google-docs](../../../agent-hands/skills/use-google-docs/SKILL.md) for operation bounds, arguments, preview/execute controls, formatting, and comment limitations. The implementation now lives there and depends on [authorize-google](../../../agent-hands/skills/authorize-google/SKILL.md).

Existing `lifeos docs COMMAND ALIAS DOC_URL_OR_ID ...` and `lifeos google auth ALIAS ...` entrypoints remain supported and keep their existing ignored account locations and Python runtime. No credential copy or reauthorization is needed for this extraction. New standalone users should follow the portable setup; do not mix its adjacent config with the legacy account route accidentally. Private document selection and workflow choices remain with the caller.
