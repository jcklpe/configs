# Slack Integration
## Purpose
Add a `lifeos slack` command surface so an agent can act in Slack **as the user's own Slack account**, under explicit per-action approval:

1. post, reply, and send direct messages as the user (not as a bot persona);
2. read and write Slack Lists records, so a List can serve as a task system the tool reconciles against;
3. do targeted reads (resolve a channel or member, fetch a thread, read back what was just posted).

This spike owns the executable tooling: auth, credentials, commands, tests, and the tool skill. How a private workflow decides *when* to message or file a List item lives outside this repo.

**Shipped 2026-09-26/27 and archived.** The first slice below was built, passed human QA against a real workspace, and gained a read-only List snapshot (`lifeos slack sync`). The todo has the build record; `lifeos-tools/skills/lifeos-slack/SKILL.md` is the operating guide.

## Identity: user token, not a bot
Slack acts with the identity of the token used:

- `chat.postMessage` accepts bot and user tokens with `chat:write`;
- a **user token** from the app's user OAuth / install flow posts as the user who authorized it;
- `chat:write.customize` only restyles a *bot's* name and avatar, so it is not the model here.

So the tool uses a small private Slack app, authorized by the user in each workspace, and a user OAuth token. Re-check Slack's current token and scope documentation before building; these are external facts that change.

References:
- https://docs.slack.dev/reference/methods/chat.postMessage/
- https://docs.slack.dev/reference/scopes/chat.write/
- https://docs.slack.dev/legacy/legacy-app-migration/differences-between-classic-apps-and-granular-slack-apps/

## Credentials and workspaces
- Tokens stay in the ignored `secrets/.env`, never in tracked files, fixtures, or docs. The account file names the environment variable, not the token.
- Authorization is per workspace. An ignored account file maps a readable alias to stable IDs and a credential reference, following the existing Google / Microsoft 365 / Odoo alias pattern, for example:

```json
{"accounts": [{"alias": "work", "team_id": "T0000000", "user_id": "U0000000", "token_env": "SLACK_TOKEN_WORK", "lists": [{"id": "F0000000", "name": "ops"}]}]}
```

- No implicit default workspace once there is more than one; the alias is always explicit.

## Scopes
Start minimal and add only when a command needs it; verify names against current docs at implementation time.

- `chat:write` — post and reply as the user.
- Channel read scopes only if name-to-ID resolution needs them.
- `users:read` only if resolving people by name needs it.
- DM / MPIM scopes only when direct messages are implemented.
- Slack Lists scopes for the `slackLists.*` methods used (read schema and items; create and update items).

## Command surface (as shipped)
```text
lifeos slack accounts
lifeos slack whoami ALIAS                     # verifies team and user IDs match the configured ones
lifeos slack channels ALIAS [QUERY]           # bounded name -> ID resolver
lifeos slack users ALIAS [QUERY]              # name -> U... ID
lifeos slack post ALIAS (--channel ID [--thread-ts TS] | --url MESSAGE_URL) (--text TEXT | --text-file FILE) [--execute]
lifeos slack dm ALIAS --user ID (--text TEXT | --text-file FILE) [--execute]
lifeos slack thread ALIAS (MESSAGE_URL | --channel ID --ts TS)
lifeos slack sync [ALIAS] [--qa | --output DIR]  # read-only Markdown snapshot of configured Lists
lifeos slack lists schema ALIAS LIST_ID
lifeos slack lists items ALIAS LIST_ID [--limit N] [--archived]
lifeos slack lists get ALIAS LIST_ID ITEM_ID
lifeos slack lists create ALIAS LIST_ID --field NAME=VALUE... [--parent ITEM_ID] [--execute]
lifeos slack lists update ALIAS LIST_ID ITEM_ID --field NAME=VALUE... [--execute]
```

Search, scheduled messages, Block Kit composition, and workspace-wide syncing wait until a real workflow needs them.

## Write safety
Every write is an outward communication or a shared-record change:

- **Dry-run by default.** The plan shows workspace alias, resolved team and user, target (channel, thread, user, or List item), and the exact final text or field values. Only `--execute` sends.
- **Identity check before sending:** confirm the token's team and user match the configured IDs; refuse on mismatch.
- **Readback after sending:** return the message timestamp and permalink, or re-read the List item, and report the verified result, never the request alone.
- **Fail loudly** on an unknown alias, missing scope, revoked or expired token, no access to the target channel, or an app not approved by the workspace admin. The error names the likely fix. No fallback to another workspace or identity.
- No delete commands.

## Slack Lists: known API facts (checked 2026-09-22)
- `slackLists.create` schema types include `link` and `reference`; the `slackLists.items.create` example represents a link value as an array. Whether a cell accepts several links is not established.
- `slackLists.update` with `todo_mode=false` hides the task-tracking bundle (Completed, Assignee, Due Date) together.
- `slackLists.items.create` documents a parent item for subtasks; nesting depth is not established.
- Verified with this tool against a real List on 2026-09-26: text, select, link, to-do assignee, to-do due date, and to-do completed writes; a subtask via `--parent`; all confirmed by readback. `reference` columns are refused rather than guessed.
- Still untested: multiple links per cell, item discussion (comment) access, which the API does not appear to expose, concurrent edits, notifications, and pagination at scale.

## Non-goals
- No bot persona and no name or avatar customization.
- No mirroring of whole workspaces or channels. The List snapshot covers only Lists named in the account config.
- No general chat-automation platform.
- No secrets, tokens, or real workspace data in the repo, fixtures, or docs.
