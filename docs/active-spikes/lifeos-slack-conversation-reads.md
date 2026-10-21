---
attention: live
---
# LifeOS Slack Conversation Reads
Opened 2026-10-21. Slug: `lifeos-slack-conversation-reads`.

## Problem and user direction
The Slack adapter could resolve people and read a known thread, but it could not discover an existing direct conversation or read its recent roots. That made a request to review a recent exchange appear inaccessible despite the existing token having the needed conversation permissions. The user authorized adding DM and related read capabilities, then explicitly directed that this CLI work be tracked as a spike in `configs`.

## Scope and ownership
This spike belongs to the `configs` repository because it owns `lifeos-tools/`. It does not modify the separate LifeOS vault, its Drive folder, or their documentation/checkpoint work. Scope is Slack read implementation, offline tests, dispatcher help, tool README, tool-local Slack skill, this spike pair, and its `TODO.md` index entry. The existing Slack List Comments spike remains separate: it addresses item discussion targeting and first-comment writes, whereas this spike addresses general conversation reads.

## Read model and boundaries
Discovery lists existing public/private channels, DMs and group DMs; a verified user-ID filter narrows direct/group conversations. Group membership is checked through the existing read API. Listing never opens a DM or joins a conversation. History reads one newest-first page with explicit continuation and optional timestamp bounds. Thread bodies remain the existing `thread` command's responsibility. `permalink` returns Slack's actual message link. Search reads a single newest-first page with result totals and page selection.

The existing authenticated account and grants are the boundary. No OAuth expansion, credential installation, browser fallback, sends, reactions or other Slack changes are authorized by this implementation task. Search results are leads subject to Slack indexing and UI filters, not proof of a complete conversation. History is subject to retention and conversation visibility, and a root's timestamp does not establish when all its replies occurred.

## Verified result and permission gap
On 2026-10-21, existing DM/group discovery, group membership filtering, DM history, thread reads and API permalinks succeeded. The originally requested direct exchange was found and its recent threads read; the summary and exact private links were returned through the task response. Private message content, participant identifiers and private links are deliberately excluded from this public repository.

`search.messages` returned `missing_scope` requiring `search:read`. No grant was expanded and no denied call was retried. The search implementation is offline-tested but cannot be live-verified with the current token. The full OAuth scope inventory was not extracted; successful API calls establish effective read capability, not an exhaustive grant list.

## Validation and next decision
The combined Python discussion/read test suite passes 29 tests, the existing Slack shell tests pass, `bash -n lifeos-tools/lifeos.sh` passes, and the diff has no whitespace errors. New tests cover identity mismatch before content reads, existing DM/group filtering, discovery pagination/incompleteness, bounded history and continuation, search page parameters, API permalinks, missing scopes without retries, and rejection of invalid bounds. Mock reads allow only the intended read methods.

The original conversation lookup is complete to the extent reported: recent direct-message roots and their replies were verified, not an exhaustive search of every older thread or group conversation. Next, return the already verified conversation summary to the user and let their follow-up determine any narrower read. Workspace-wide search remains blocked unless the user separately approves an exact OAuth expansion. Keep this spike live until closure is explicitly authorized; no archival is implied by the implementation checkpoint.

## Maintained guidance
Command behavior and examples live in `lifeos-tools/README.md`, `lifeos-tools/lifeos.sh` help, and `lifeos-tools/skills/lifeos-slack/SKILL.md`.
