---
attention: live
---
# LifeOS Slack Conversation Reads — Tasks
Opened 2026-10-21. Slug: `lifeos-slack-conversation-reads`. Conceptual context: [LifeOS Slack Conversation Reads](lifeos-slack-conversation-reads.md).

## Current State
Implementation and existing-access integration reads are verified. General message search is implemented and mock-tested, but live search is blocked by the current token's missing `search:read` scope. No OAuth changes, browser fallback or Slack writes occurred.

## To Do
- If broader search is needed, obtain explicit approval for the exact `search:read` grant before changing authorization, then live-verify `search`. Otherwise keep the scope limitation documented; existing-access history reads do not depend on search access.
- Review and authorize spike closure before any historical transition or archival.

## Ready for Human QA
- None required for the terminal-verifiable existing-access reads. Search live verification is permission-blocked, not a human UI QA request.

## Done
- Add read-only conversation listing including existing DMs and group DMs. Implemented `conversations` with types, archived inclusion, participant filtering and bounded full pagination; live existing-DM/group discovery and membership checks succeeded.
- Add bounded conversation history sufficient to locate recent messages. Implemented `history` with limit, cursor, time bounds, explicit continuation/end marker and thread metadata; recent direct-message roots and relevant replies were read successfully using existing access.
- Add read-only message search. Implemented `search` with newest-first ordering, bounded result pages, totals and API permalinks. Offline verification passes; live `search.messages` returned `missing_scope` requiring `search:read` once, with no expansion or retry.
- Add message permalink lookup. Implemented `permalink`; live API-returned direct-message links succeeded.
- Preserve existing APIs and add tests/help/docs. Existing Slack tests pass; combined Python suite passes 29 tests including eight new read-command tests. Dispatcher syntax, help and whitespace checks pass. Updated only Slack implementation, its directly associated tests and tool guidance.
- Record this CLI work as a bounded spike in the owning repository. Added this pair with `attention: live` and a `TODO.md` index entry.

## Verification Commands
```sh
PYTHONDONTWRITEBYTECODE=1 python3 agent-hands/compat/lifeos/tests/test-slack-comments.py
bash agent-hands/compat/lifeos/tests/test-slack.sh
bash -n agent-hands/compat/lifeos/lifeos.sh
git diff --check
```
