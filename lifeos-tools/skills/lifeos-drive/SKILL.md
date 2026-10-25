---
name: lifeos-drive
description: "Use legacy lifeos drive commands while routing their service mechanics to the portable Google Drive skill."
---

# Legacy Drive Route
Read [use-google-drive](../../../agent-hands/skills/use-google-drive/SKILL.md) for supported operations, bounds, account/write controls, download safety, and index limitations. It depends only on [authorize-google](../../../agent-hands/skills/authorize-google/SKILL.md).

Existing `lifeos drive` commands retain their ignored account paths and runtime. `sync` remains a compatibility wrapper for the portable `export-index`; it preserves the existing caller's output destination, QA option, and configured folder exclusions. The implicit private exclusion default is retired: pass `--exclude-folder NAME` (repeatable) or set `drive.index_exclude` explicitly. Without either, the compatibility sync stops before retrieval; an explicit empty array deliberately allows all top-level child samples. New portable use requires an explicit index output. No credential copy or authorization change is required by this extraction.

Folder exclusions only skip selected top-level child listings; they do not filter the account-wide recent sample or arbitrary searches. Treat generated indexes as private metadata unless their content and sharing scope have been reviewed. Private workspace conventions and publication choices belong to the consuming workflow, not the portable tool.

`lifeos drive sync ALIAS --recent 0` delegates the portable option that skips the account-wide recent-file query entirely. Folder exclusions still expose their names and do not constrain ordinary search/read operations. The private consuming workflow decides when this narrower export is required.
