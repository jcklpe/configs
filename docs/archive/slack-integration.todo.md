# Slack Integration — Todo
See [the conceptual spike](slack-integration.md). Opened 2026-09-26; built and QA'd 2026-09-26; List snapshot added and spike archived 2026-09-27.

## Current State
- **Done and archived 2026-09-27.** `lib/slack.py` (Python, stdlib only) behind `lib/slack.sh` and `lifeos slack ...`; ignored `secrets/slack-accounts.json` with `slack-accounts.example.json`; tool skill `skills/lifeos-slack/SKILL.md`, linked globally for Codex and Claude by the installer; offline tests `tests/test-slack.sh`. Live QA passed against a real workspace on 2026-09-26.
- The design (identity model, credentials, scopes, command surface, write safety, Slack Lists API facts) is in the conceptual doc.

## To Do
### Setup and identity
- [x] Re-verify current Slack docs: user-token OAuth flow, "post as the authorizing user" behavior, and the scope names for each planned command.
- [x] Decide app setup: one private app per workspace or one app installed in several; document whether workspace admin approval is needed.
- [x] Add the ignored account file and alias loader, following the Google / Microsoft 365 / Odoo alias pattern.
- [x] Add a `lifeos doctor` check that reports whether each alias's token variable is set, never its value.
- [x] Implement `accounts` and `whoami` (team and user IDs must match the configured ones).

### Messaging
- [x] `channels` resolver (bounded), plus a `users` resolver so a person can be addressed by name before a DM.
- [x] `post` and `reply`: dry-run plan, identity check, `--execute`, readback with timestamp and permalink.
- [x] `dm` (`conversations.open`, then the same send path).
- [x] `thread` read for a single thread, by message URL or channel and ts.

### Slack Lists
- [x] `lists schema`, `lists items` (paged), and `lists get` reads.
- [x] `lists create` and `lists update` with dry-run, `--execute`, and readback via `slackLists.items.info`.
- [x] Test the field types against a real List (2026-09-26, with the user's approval, on a clearly labeled test item the user deletes afterwards): create with text, select, link, to-do assignee, and to-do due date; update of select, to-do completed (checkbox), date, text, and link; subtask via `--parent`. All confirmed by readback. `reference` columns remain unsupported (refused).

### Quality
- [x] Offline tests with invented fixtures: plan rendering and dry-run not sending, identity-mismatch and bot-token refusal, misattributed-post failure, thread replies by URL, DM, typed List fields and their refusals, create with readback, and runaway paging. Slack-side error hints (`missing_scope`, `token_revoked`) are mapped in code but only exercised live.
- [x] Tool skill `lifeos-tools/skills/lifeos-slack/SKILL.md` (with the app manifest and setup steps), README examples, and a `lifeos-cli` pointer. `lifeos-slack` was missing from the installer's symlink blocks; added for Codex and Claude and the symlink step rerun 2026-09-27 (this also linked the previously unlinked `lifeos-odoo`).
- [x] Human QA (2026-09-26): `whoami` confirmed a user token for the configured user; a self-DM, a threaded reply by message URL, and thread reads all appeared under the user's own account, with permalinks returned; List reads, creates, and updates as above. Live use surfaced two display fixes (select cells showed option IDs; link cells showed raw JSON), both fixed with tests.

## Decisions and findings (2026-09-26)
- Docs checked: `chat.postMessage` with a user token posts as that user; `slackLists.items.list`/`info` accept user tokens with `lists:read`, `items.create`/`update` with `lists:write`; Lists need a paid plan; List schema is at `list.list_metadata.schema` (column `id`, `key`, `name`, `type`, `options.choices[].value/label`); `items.update` takes `cells` with `row_id` and `column_id`.
- Setup uses the app settings page's **Install to Workspace** and its User OAuth Token, so no local OAuth redirect flow (Slack requires HTTPS redirect URIs) and no token rotation. One small app per workspace, created from the manifest in the skill.
- Writes refuse a bot token, a team/user mismatch, and a posted message attributed to anyone else. Reads are form-encoded; structured writes send JSON.
- Field encodings for user, date, link, and checkbox follow Slack's documented examples and were confirmed against a real List in the 2026-09-26 QA; other column types are refused.

### List snapshot (2026-09-27)
- [x] `lifeos slack sync [ALIAS] [--qa | --output DIR]` writes each List named under an account's `"lists"` to `sources/slack/<alias>/list-<name>.md`: items grouped by Status in the List's choice order, record links, assignees by name, other fields, and descriptions rendered from rich text to Markdown (bold, italics, code, links, bullet and numbered lists, quotes). Atomic write; fails if an alias names no lists. Offline tests added; a live QA run rendered a real 51-item List correctly.
- Rationale: agents reconciling meeting notes against a List need a cheap orientation read, like the Trello and GitHub snapshots. Writes still re-read the live item first.

## Notes
- Never commit real workspace names, channel or List IDs, member names, or message content; fixtures use invented IDs such as `T0000000`.
