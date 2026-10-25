---
name: lifeos-drive
description: "Use legacy lifeos drive commands while routing their service mechanics to the portable Google Drive skill."
---

# Legacy Drive Route
Read [use-google-drive](../../../agent-hands/skills/use-google-drive/SKILL.md) for supported operations, bounds, account/write controls, download safety, and index limitations. It depends only on [authorize-google](../../../agent-hands/skills/authorize-google/SKILL.md).

Both `lifeos drive` and standalone commands use the provider's adjacent ignored configuration and the capability's runtime. `sync ALIAS --output FILE` remains a compatibility spelling for `export-index`. The implicit destination and `--qa` option are retired. The compatibility route also requires `--exclude-folder NAME` (repeatable) or an explicit `drive.index_exclude` array; an empty array deliberately allows all top-level child samples. The consuming workspace supplies its exclusions and snapshot destination.

Folder exclusions only skip selected top-level child listings; they do not filter the account-wide recent sample or arbitrary searches. Treat generated indexes as private metadata unless their content and sharing scope have been reviewed. Private workspace conventions and publication choices belong to the consuming workflow, not the portable tool.

`lifeos drive sync ALIAS --recent 0 --output FILE` delegates the portable option that skips the account-wide recent-file query entirely. Folder exclusions still expose their names and do not constrain ordinary search/read operations. The private consuming workflow decides when this narrower export is required.
