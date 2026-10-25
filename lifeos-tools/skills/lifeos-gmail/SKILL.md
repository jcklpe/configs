---
name: lifeos-gmail
description: "Use the legacy lifeos Gmail command with provider-owned configuration and explicit export destinations."
---
# Legacy Gmail Route
Read [use-gmail](../../../agent-hands/skills/use-gmail/SKILL.md) for operations, limits, preview/execute controls, readback, and partial failures. Both entrypoints use [authorize-google](../../../agent-hands/skills/authorize-google/SKILL.md)'s adjacent ignored configuration and the capability's runtime and audit log.

`lifeos gmail sync ALIAS --output FILE` forwards to `gmail export`. Optional `--query` and `--max-results` work with that explicit destination. `--all`, `--qa`, implicit private paths, and automatic indexes are retired. The consuming workflow selects accounts, preserves its maintained query/window, chooses separate outputs for broader one-off searches, and reports each failed refresh. Failed retrieval preserves the previous account output.

Other subcommands retain their existing syntax and gates. Private fallback query choices must be explicit account settings; no private label exclusion is built into this compatibility route. `GOOGLE_GMAIL_MAX_RETRIES` is the provider-owned retry setting. Authentication is not approval to read another account or write mail. No send or message-delete capability is introduced.
