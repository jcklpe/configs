---
attention: live
---
# Direct Excel workbook operations
Opened 2026-10-22. Slug: `lifeos-m365-excel`. Implementation work: [tasks](lifeos-m365-excel.todo.md).

## Purpose and authorized scope
Add bounded Microsoft Graph Excel operations to `lifeos m365` so shared workbooks can be edited at worksheet, range and table level without downloading and replacing the whole file. The user requested implementation through a project spike. This authorizes local tooling work and read-only capability checks, not changes to authentication grants or arbitrary shared workbook content.

## Design
Reuse the existing delegated Graph transport and file feature/write flags. Do not add a generic Graph request command, inspect token caches, or change configured scopes. The initial command surface covers worksheet/table discovery, bounded range reads and writes, worksheet/table creation, table properties and batched row append, and range formatting. Preview before mutation, require the preview fingerprint at execution, read back the requested effects, and audit attempts without logging cell contents. Fail on malformed input, stale previews, unsupported workbook types, incomplete responses and mismatched readback.

Graph workbook changes are not transactions and do not provide the file replacement route's documented atomic If-Match guarantee. A preflight fingerprint detects changes before sending a request but cannot prevent a simultaneous human edit between check and write. Work on different areas when coauthoring; report uncertain outcomes and inspect before repeating a mutation. Sessions can improve performance but do not supply exclusive locks or rollback. Start with documented sessionless operations, which persist individual writes, avoiding any claim of transactional batches.

## Authentication and verification
Microsoft's endpoint permission tables list delegated `Files.ReadWrite` and do not support application permissions. Existing file access uses `Files.ReadWrite.All`; test the configured account through bounded reads rather than infer effective workbook permission from file access. No automatic consent/authentication expansion. Offline transport tests establish command safety and request shape; live reads establish only read capability; live writes and browser coauthoring require separate verification.

## Sources
Checked October 22, 2026: [Excel API overview](https://learn.microsoft.com/en-us/graph/api/resources/excel?view=graph-rest-1.0), [range update](https://learn.microsoft.com/en-us/graph/api/range-update?view=graph-rest-1.0), [table creation](https://learn.microsoft.com/en-us/graph/api/tablecollection-add?view=graph-rest-1.0), [row append](https://learn.microsoft.com/en-us/graph/api/tablerowcollection-add?view=graph-rest-1.0), [range formatting](https://learn.microsoft.com/en-us/graph/api/rangeformat-update?view=graph-rest-1.0), [sessions](https://learn.microsoft.com/en-us/graph/api/workbook-createsession?view=graph-rest-1.0), [best practices](https://learn.microsoft.com/en-us/graph/workbook-best-practice).
