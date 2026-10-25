---
name: lifeos-gmail
description: "Use the legacy lifeos Gmail route while its callers migrate to the portable use-gmail capability. Covers existing snapshot routing and retained private account configuration."
---

# LifeOS Gmail Compatibility Route
Read [use-gmail](../../../agent-hands/skills/use-gmail/SKILL.md) for supported operations, bounds, preview/execute controls, readback limits, and partial failures. The legacy `lifeos gmail` command delegates to that implementation while keeping its existing private Google accounts and shared mail audit path. Use `lifeos google auth ALIAS` for this route's configured credentials; do not accidentally authorize the portable route's separate default config.

`lifeos gmail sync ALIAS` and `--all` retain the existing workspace snapshot destination, per-account query, index, and QA routing. The fallback query remains `in:inbox newer_than:30d -label:Newsletters`. Query/count overrides require `--output FILE` or `--qa`, preserving the ordinary snapshot contract. Failed retrieval leaves the prior account output intact; all-account sync continues and reports failed accounts. `LIFEOS_GMAIL_MAX_RETRIES` retains the legacy backoff setting.

Other subcommands keep their existing `lifeos gmail` syntax. Real account selection, snapshot destinations, triage decisions, and approval rules belong to ignored configuration and the calling workspace. This bridge does not migrate credentials, regenerate snapshots, install global skills, or grant mail-write permission.
