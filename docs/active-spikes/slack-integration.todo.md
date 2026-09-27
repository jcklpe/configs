# Slack Integration — Todo
See [the conceptual spike](slack-integration.md). Opened 2026-09-26; not being built yet.

## Current State
- No Slack code exists in `lifeos-tools`.
- The design (identity model, credentials, scopes, command surface, write safety, Slack Lists API facts) is in the conceptual doc.

## To Do
### Setup and identity
- [ ] Re-verify current Slack docs: user-token OAuth flow, "post as the authorizing user" behavior, and the scope names for each planned command.
- [ ] Decide app setup: one private app per workspace or one app installed in several; document whether workspace admin approval is needed.
- [ ] Add the ignored account file and alias loader, following the Google / Microsoft 365 / Odoo alias pattern; add a `doctor` check that never prints secrets.
- [ ] Implement `accounts` and `whoami` (team and user IDs must match the configured ones).

### Messaging
- [ ] `channels` resolver (bounded).
- [ ] `post` and `reply`: dry-run plan, identity check, `--execute`, readback with timestamp and permalink.
- [ ] `dm`, once a workflow needs it.
- [ ] `thread` read for a single thread.

### Slack Lists
- [ ] `lists schema` and `lists items` reads, with paging.
- [ ] `lists create` and `lists update` with dry-run, `--execute`, and readback.
- [ ] Test the unverified field types (assignee, due date, link, reference) against a throwaway List before relying on them.

### Quality
- [ ] Offline tests with invented fixtures: plan rendering, identity mismatch refusal, missing-scope and revoked-token errors, readback parsing.
- [ ] Tool skill `lifeos-tools/skills/lifeos-slack/SKILL.md` and README entry.
- [ ] Human QA: a real post and a real List write, confirmed to appear under the user's own account.

## Notes
- Never commit real workspace names, channel or List IDs, member names, or message content; fixtures use invented IDs such as `T0000000`.
