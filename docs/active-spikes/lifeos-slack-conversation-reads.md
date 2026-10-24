---
attention: live
---
# LifeOS Slack Conversation Reads
Opened 2026-10-21. Slug: `lifeos-slack-conversation-reads`.

## Problem and user direction
The Slack adapter could resolve people and read a known thread, but it could not discover an existing direct conversation or read its recent roots. General conversation lookup therefore required additional read-only CLI commands. This spike tracks those additions in the repository that owns the tools.

## Scope and ownership
This spike belongs to the `configs` repository because it owns `lifeos-tools/`. Scope is Slack read implementation, offline tests, dispatcher help, tool README, tool-local Slack skill, this spike pair, and its `TODO.md` index entry. The existing Slack List Comments spike remains separate: it addresses item discussion targeting and first-comment writes, whereas this spike addresses general conversation reads.

## Read model and boundaries
Discovery lists existing public/private channels, DMs and group DMs; a verified user-ID filter narrows direct/group conversations. Group membership is checked through the existing read API. Listing never opens a DM or joins a conversation. History reads one newest-first page with explicit continuation and optional timestamp bounds. Thread bodies remain the existing `thread` command's responsibility. `permalink` returns Slack's actual message link. Search reads a single newest-first page with result totals and page selection.

The existing authenticated account and grants are the boundary. No OAuth expansion, credential installation, browser fallback, sends, reactions or other Slack changes are authorized by this implementation task. Search results are leads subject to Slack indexing and UI filters, not proof of a complete conversation. History is subject to retention and conversation visibility, and a root's timestamp does not establish when all its replies occurred.

## Verified result and permission gap
Live integration checks covered existing DM/group discovery, group membership filtering, DM history, thread reads and API permalinks. This public repository contains only generic implementation evidence and synthetic test data; source messages, participant identifiers, private links, account configuration and surrounding private project context are excluded.

`search.messages` returned `missing_scope` requiring `search:read`. No grant was expanded and no denied call was retried. The search implementation is offline-tested but cannot be live-verified with the current token. The full OAuth scope inventory was not extracted; successful API calls establish effective read capability, not an exhaustive grant list.

## Validation and next decision
The combined Python discussion/read test suite passes 29 tests, the existing Slack shell tests pass, `bash -n lifeos-tools/lifeos.sh` passes, and the diff has no whitespace errors. New tests cover identity mismatch before content reads, existing DM/group filtering, discovery pagination/incompleteness, bounded history and continuation, search page parameters, API permalinks, missing scopes without retries, and rejection of invalid bounds. Mock reads allow only the intended read methods.

Live search verification remains blocked unless the user separately approves an exact OAuth expansion. A history page plus selected thread reads does not establish an exhaustive search across older threads and group conversations. Keep this spike live until closure is explicitly authorized; no archival is implied by the implementation checkpoint.

## Maintained guidance
Command behavior and examples live in `lifeos-tools/README.md`, `lifeos-tools/lifeos.sh` help, and `lifeos-tools/skills/lifeos-slack/SKILL.md`.
