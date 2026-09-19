# Odoo CLI — To Do
## Current State
- Odoo 19 JSON-2 and `/doc` are the intended protocol and discovery surfaces.
- The target server identifies itself as Odoo Online `saas~19.4+e` and exposes `/doc`.
- Official documentation says external API access is plan-gated, but authenticated project and task reads succeeded on the current free account on 2026-09-19. This is observed, unsupported behavior with no explicit published cap.
- The CLI now has account configuration, a JSON-2 transport, bounded project/stage/task reads, and a configured live API key.
- Each read command makes one request; an executed write makes one mutation request and one required readback. There are no automatic retries or pagination. A five-second cross-request cooldown reduces accidental bursts; normal use should remain on demand rather than polling.

## To Do
- [ ] Add a current-user/profile read if live method discovery identifies a stable bounded call.
- [x] Implement bounded task create/update/comment plans that are dry-run by default and require `--execute`.
- [x] Require exact numeric project/task/stage/assignee identities for writes and read each changed task back after execution.
- [x] Add synthetic write tests for request construction, dry-run behavior, explicit clear/conflict handling, and readback.
- [ ] Document setup, supported commands, permission/plan requirements, and known limitations.
- [ ] Run the full offline test suite and one live read/write/readback validation against an approved test record.

## Ready for Human QA
- Preview and execute a create or update against an approved disposable test record, then confirm the required task readback reflects the requested fields.

## Done
- [x] Inspect the supported Odoo 19 integration model. JSON-2 is the documented current API, `/doc` exposes database-specific models/methods, API keys use bearer authentication, access follows the authenticating user’s record rules, and external API availability depends on plan eligibility.
- [x] Add an ignored account-alias configuration and public-safe example with HTTPS URL, optional database header value, and API-key environment variable name.
- [x] Add doctor checks that validate configuration and report API-key presence without printing secrets.
- [x] Implement a bounded JSON-2 transport with structured HTTP errors and no arbitrary model/method command.
- [x] Implement project and stage listing plus task list/search/exact-read commands with deterministic text and `--json` output.
- [x] Add synthetic project, stage, and task fixtures; verify request domains, bounded limits, formatting, exact numeric IDs, and the full pre-existing offline suite.
- [x] Add and validate a tool-specific Odoo skill, durable CLI documentation, and installer symlinks for Codex and Claude.
- [x] Create a scoped, expiring API key and verify authenticated JSON-2 reads against one project and one bounded task result on 2026-09-19.
- [x] Add conservative request behavior: one request per read, one mutation plus readback per executed write, no automatic retry or pagination, and a five-second cross-request cooldown.
- [x] Add a bounded exact-task comment listing so comment writes can be verified against `mail.message` rather than inferred from the task record's unchanged `write_date`.
- [x] Execute an approved plain-text comment on the existing test task and verify comment ID `373` contains the exact submitted body on 2026-09-19.
- [x] Human QA confirmed on 2026-09-19 that the submitted comment is visible in the Odoo interface.

## Notes / Edge Cases
- The runtime documentation being visible does not establish that API-key calls are enabled.
- Model fields and allowed methods vary by database; prefer runtime discovery during development but keep the shipped command contract narrow.
- Odoo API keys can carry broad user-equivalent access. Store them as secrets, rotate them, and keep CLI capabilities narrower than the credential.
- Successful access on a free account is not a promise of support or continued eligibility. Keep request volume low and treat permission, quota, or plan errors as hard boundaries.
