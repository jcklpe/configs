---
attention: live
---
# LifeOS Slack List Comments
## Purpose and boundaries
Add bounded List item discussion reads and comments to the existing user-token CLI. The interface must prove the discussion belongs to the requested List and record, retain dry-run-first writes and identity checks, and obtain real API permalinks. No new credentials, scope expansion, browser automation, live test messages, or changes to List task completion state are part of this implementation.

Continues from: docs/archive/slack-integration.md

## Supported model
A supplied existing comment permalink provides a conversation and root timestamp. Read-only verification found a `list_record_comment` root with `slack_list.list_id` and `slack_list.list_record_id`; the implementation requires those exact associations and fails closed if absent. This observed metadata is not documented as a stable public contract. The ordinary documented conversation/reply methods read and post to that thread; `chat.getPermalink` supplies links.

The public Lists item-info response and the checked live item provide no discussion locator. Automatic discovery and first-comment creation from List/record IDs alone remain unsupported. A record's creation timestamp is not a thread timestamp; a List ID is not evidence of a conversation ID. Requiring a copied real comment URL avoids guessing either.

## Evidence and maintained guidance
On 2026-10-17, the existing configured user token matched its expected workspace and user. Its granted scopes included Lists read/write, chat write, and conversation histories. Read-only calls verified the supplied existing discussion, its exact List/record association, three replies, and an API-returned permalink for the supplied comment. No private task content, actual workspace IDs, tokens, or source links belong in this public spike.

Official references: [item info](https://docs.slack.dev/reference/methods/slackLists.items.info/), [thread reads](https://docs.slack.dev/reference/methods/conversations.replies/), [posting](https://docs.slack.dev/reference/methods/chat.postMessage/), [permalinks](https://docs.slack.dev/reference/methods/chat.getPermalink/). Current operation belongs in `lifeos-tools/skills/lifeos-slack/SKILL.md` and `lifeos-tools/README.md`.

## Verification limits
Offline tests cover dry run, identity and association refusal, paging, send/readback/permalink sequencing, scope failures, and partial or uncertain outcomes. Live sending remains pending a specifically approved destination and message. Keep this spike active; closure has not been authorized.
