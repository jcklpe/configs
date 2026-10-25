---
attention: live
---
# LifeOS Slack List Comments Tasks
## Background
Slug: `lifeos-slack-list-comments`. Add the smallest supported discussion interface without guessing IDs, changing persistent permissions, posting test messages, or closing the spike.
## Current State
Implemented automatic per-item root discovery in a known List conversation, URL-free reads, and dry-run-first comments including first user comments on existing zero-reply roots. Live reads verified; offline checks recorded below. No Slack writes were performed in this work.
## To Do
- Obtain a specifically approved live destination and comment before exercising `lists comment --execute`; do not duplicate an existing real comment.
- Keep the spike open pending explicit closure authorization.
## Ready for Human QA
- Verify one specifically approved comment send, author, rendered text, discussion association, and API permalink in Slack. If Slack normalizes text, inspect any `PARTIAL` result before considering a retry.
## Done
- Inspect CLI, official APIs, existing identity/scopes, and supplied discussion read-only. Verified user identity, available scopes, root association, three existing replies, and real API permalink. Item metadata lacks a thread locator.
- Add bounded List item comments read/post commands with dry-run-first behavior, target/identity checks, readback, and API permalinks. `lists comments` and `lists comment` initially required a copied existing comment URL and refused mismatched or missing root metadata. Follow-up history discovery below removes the per-item URL requirement. Partial/uncertain sends are surfaced without automatic retries.
- Add offline tests and maintained CLI/skill documentation. Test commands: `python3 agent-hands/compat/lifeos/tests/test-slack-comments.py` and `bash agent-hands/compat/lifeos/tests/test-slack.sh`; both pass (11 new unittest cases plus existing Slack regression checks). The new read command also passed against the supplied live discussion and returned its API root permalink. A bounded scan found no invalidated vault skill assumptions. New tests use invented IDs and text only.
- Investigate supported conversation/history/search routes and official SDKs beyond item-info metadata. Full conversation listings omitted the known file discussion, but history exposed a matching root for every current List item, including many with no replies. This corrects the initial first-comment limitation; user comments can target those roots without creating a new root.
- Add automatic history discovery and verified per-List mapping. `discussion_channel_id` is now supported in account List entries, with optional `--channel` / `--url` overrides. The supplied List's verified mapping was saved only in ignored local config; no credentials or permissions changed. Missing/ambiguous roots, stale mappings, pagination failures, and mismatched root readback are refused. URL-free reads passed live for the supplied item and a zero-reply item. All 21 offline cases plus existing Slack regression checks pass; first-comment sends are mock-tested only.
## Remaining API limitation
A previously unknown List needs a verified discussion conversation mapping; inspected metadata and current scopes did not provide a lookup. `files.info` was denied with `missing_scope` for `files:read`, and message search requires absent `search:read`; neither additional scope is proven to solve bootstrap. No supported method for creating a genuinely missing root was established in public Lists methods or official SDK types. This is distinct from first comments on the accessible roots already present. Live sending remains pending specific approval. No Slack writes or permission changes occurred.
