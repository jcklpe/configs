# Odoo CLI — To Do
## Current State
- Odoo 19 JSON-2 and `/doc` are the intended protocol and discovery surfaces.
- The target server identifies itself as Odoo Online `saas~19.4+e` and exposes `/doc`.
- Official documentation says external API access is plan-gated; live API-key eligibility is not yet verified.
- The CLI now has account configuration, a JSON-2 transport, and bounded project/stage/task reads. The real ignored alias is configured but has no API key yet.

## To Do
- [ ] Create a scoped, expiring API key and verify that an authenticated JSON-2 `project.project` read is permitted.
- [ ] Add a current-user/profile read if live method discovery identifies a stable bounded call.
- [ ] Implement task create/update/comment plans that are dry-run by default and require `--execute`.
- [ ] Require exact project/task/stage/assignee identities for writes and read each changed task back after execution.
- [ ] Add synthetic fixtures and tests for request construction, pagination or result bounds, renderers, dry-run behavior, readback, and error redaction.
- [ ] Document setup, supported commands, permission/plan requirements, and known limitations.
- [ ] Run the full offline test suite and one live read/write/readback validation against an approved test record.

## Ready for Human QA
None yet.

## Done
- [x] Inspect the supported Odoo 19 integration model. JSON-2 is the documented current API, `/doc` exposes database-specific models/methods, API keys use bearer authentication, access follows the authenticating user’s record rules, and external API availability depends on plan eligibility.
- [x] Add an ignored account-alias configuration and public-safe example with HTTPS URL, optional database header value, and API-key environment variable name.
- [x] Add doctor checks that validate configuration and report API-key presence without printing secrets.
- [x] Implement a bounded JSON-2 transport with structured HTTP errors and no arbitrary model/method command.
- [x] Implement project and stage listing plus task list/search/exact-read commands with deterministic text and `--json` output.
- [x] Add synthetic project, stage, and task fixtures; verify request domains, bounded limits, formatting, exact numeric IDs, and the full pre-existing offline suite.
- [x] Add and validate a tool-specific Odoo skill, durable CLI documentation, and installer symlinks for Codex and Claude.

## Notes / Edge Cases
- The runtime documentation being visible does not establish that API-key calls are enabled.
- Model fields and allowed methods vary by database; prefer runtime discovery during development but keep the shipped command contract narrow.
- Odoo API keys can carry broad user-equivalent access. Store them as secrets, rotate them, and keep CLI capabilities narrower than the credential.
