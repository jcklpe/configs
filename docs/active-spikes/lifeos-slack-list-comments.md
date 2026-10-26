---
attention: live
---
# LifeOS Slack List Comments

Current ownership (2026-10-25): Agent Hands owns native service code and `compat/lifeos/` owns the optional legacy command. Remaining references to the former `lifeos-tools/` tree describe original scope or completed historical work, not an active tool location.

## Purpose and boundaries
Add bounded List item discussion reads and comments to the existing user-token CLI. The interface must prove the discussion belongs to the requested List and record, retain dry-run-first writes and identity checks, and obtain real API permalinks. No new credentials, scope expansion, browser automation, live test messages, or changes to List task completion state are part of this implementation.

Continues from: docs/archive/slack-integration.md

## Supported model
The first implementation required a copied existing comment permalink, verified its `list_record_comment` root and exact `slack_list.list_id` / `list_record_id`, and used ordinary conversation/reply methods. A deeper read-only investigation corrected that interface limit: `conversations.history` in the known List discussion conversation exposes item roots, including roots with zero user replies. The CLI can discover each item's timestamp and target its first user comment without an existing comment URL.

The current interface uses per-List `discussion_channel_id` metadata in the existing ignored account config, or `--channel ID`, to scan bounded history. A unique matching root is rechecked through `conversations.replies` before use. A real comment URL remains optional. No conversation IDs or timestamps are derived from List/record IDs; no new credentials or permission grants are involved. Association metadata remains observed rather than a documented stable contract, so it is checked on every use.

## Bootstrap and root-creation limits
The previous conclusion that first comments were generally unsupported was too broad: all current items in the checked List had roots, many without replies. A true absence of an accessible root is a separate case; no public root-creation method was found in the documented Lists methods or official SDK request types. The CLI fails rather than manufacturing a root.

The remaining discovery gap is finding a previously unknown List's file discussion conversation. Both item-info and item-list metadata lacked a locator. Fully paged `conversations.list` and `users.conversations` omitted the known file conversation; `conversations.info` identifies it as `is_file` / `is_thread_only` when given its real ID. `files.info` requires the currently absent `files:read`, and message search requires the absent `search:read`. Additional permissions may permit more investigation, but neither is proven to solve lookup. No scopes were added and no undocumented endpoints, browser credentials, or guessed IDs were used. A verified local List-to-conversation mapping supplies the bootstrap for the user's configured List.

## Evidence and maintained guidance
On 2026-10-17, the existing configured user token matched its expected workspace and user. Its granted scopes included Lists read/write, chat write, and conversation histories. Read-only calls verified the supplied existing discussion, its exact List/record association, three replies, and an API-returned permalink for the supplied comment. No private task content, actual workspace IDs, tokens, or source links belong in this public spike.

Official SDK sources: [Lists request types](https://github.com/slackapi/node-slack-sdk/blob/main/packages/web-api/src/types/request/slackLists.ts), [chat request types](https://github.com/slackapi/node-slack-sdk/blob/main/packages/web-api/src/types/request/chat.ts), [Python conversation methods](https://github.com/slackapi/python-slack-sdk/blob/main/slack_sdk/web/client.py). Official references: [history](https://docs.slack.dev/reference/methods/conversations.history/), [item info](https://docs.slack.dev/reference/methods/slackLists.items.info/), [thread reads](https://docs.slack.dev/reference/methods/conversations.replies/), [posting](https://docs.slack.dev/reference/methods/chat.postMessage/), [permalinks](https://docs.slack.dev/reference/methods/chat.getPermalink/). Current operation belongs in `agent-hands/use-slack-lists/SKILL.md`; legacy command routing is documented in `agent-hands/compat/lifeos/skills/lifeos-slack/SKILL.md`.

## Verification limits
Offline tests cover automatic discovery, zero-reply-root first-comment targeting, dry run, identity and association refusal, paging, duplicate/missing roots, send/readback/permalink sequencing, scope failures, and partial or uncertain outcomes. Live URL-free reads verified both an existing discussion and a zero-reply root. Live sending remains pending a specifically approved destination and message. Keep this spike active; closure has not been authorized.
