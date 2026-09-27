# Slack Integration — Todo
See [the conceptual spike](slack-integration.md). Opened 2026-09-26; first build the same day, awaiting live setup and QA.

## Current State
- First slice built 2026-09-26: `lib/slack.py` (Python, stdlib only) behind `lib/slack.sh` and `lifeos slack ...`; ignored `secrets/slack-accounts.json` with `slack-accounts.example.json`; tool skill `skills/lifeos-slack/SKILL.md`; offline tests `tests/test-slack.sh`. Nothing has touched a real workspace yet.
- The design (identity model, credentials, scopes, command surface, write safety, Slack Lists API facts) is in the conceptual doc.

## To Do
### Setup and identity
- [x] Re-verify current Slack docs: user-token OAuth flow, "post as the authorizing user" behavior, and the scope names for each planned command.
- [x] Decide app setup: one private app per workspace or one app installed in several; document whether workspace admin approval is needed.
- [x] Add the ignored account file and alias loader, following the Google / Microsoft 365 / Odoo alias pattern.
- [ ] Add a `lifeos doctor` check that reports whether each alias's token variable is set, never its value.
- [x] Implement `accounts` and `whoami` (team and user IDs must match the configured ones).

### Messaging
- [x] `channels` resolver (bounded), plus a `users` resolver so a person can be addressed by name before a DM.
- [x] `post` and `reply`: dry-run plan, identity check, `--execute`, readback with timestamp and permalink.
- [x] `dm` (`conversations.open`, then the same send path).
- [x] `thread` read for a single thread, by message URL or channel and ts.

### Slack Lists
- [x] `lists schema`, `lists items` (paged), and `lists get` reads.
- [x] `lists create` and `lists update` with dry-run, `--execute`, and readback via `slackLists.items.info`.
- [ ] Test the unverified field types (assignee, due date, link, reference) against a throwaway List before relying on them.

### Quality
- [x] Offline tests with invented fixtures: plan rendering, identity mismatch refusal, missing-scope and revoked-token errors, readback parsing.
- [x] Tool skill `lifeos-tools/skills/lifeos-slack/SKILL.md` (with the app manifest and setup steps), README examples, and a `lifeos-cli` pointer. The installer's skill symlinks need a rerun to expose `lifeos-slack` to agents globally.
- [ ] Human QA: a real post and a real List write, confirmed to appear under the user's own account.

## Decisions and findings (2026-09-26)
- Docs checked: `chat.postMessage` with a user token posts as that user; `slackLists.items.list`/`info` accept user tokens with `lists:read`, `items.create`/`update` with `lists:write`; Lists need a paid plan; List schema is at `list.list_metadata.schema` (column `id`, `key`, `name`, `type`, `options.choices[].value/label`); `items.update` takes `cells` with `row_id` and `column_id`.
- Setup uses the app settings page's **Install to Workspace** and its User OAuth Token, so no local OAuth redirect flow (Slack requires HTTPS redirect URIs) and no token rotation. One small app per workspace, created from the manifest in the skill.
- Writes refuse a bot token, a team/user mismatch, and a posted message attributed to anyone else. Reads are form-encoded; structured writes send JSON.
- Field encodings for user, date, link, and checkbox follow Slack's documented examples and are unverified against a real List; other column types are refused.

## Notes
- Never commit real workspace names, channel or List IDs, member names, or message content; fixtures use invented IDs such as `T0000000`.
