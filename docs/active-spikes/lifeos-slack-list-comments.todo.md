---
attention: live
---
# LifeOS Slack List Comments Tasks
## Background
Slug: `lifeos-slack-list-comments`. Add the smallest supported discussion interface without guessing IDs, changing persistent permissions, posting test messages, or closing the spike.
## Current State
Implemented existing-discussion reads and dry-run-first replies. Live reads verified; offline checks recorded below. No Slack writes were performed in this work.
## To Do
- Obtain a specifically approved live destination and comment before exercising `lists comment --execute`; do not duplicate an existing real comment.
- Keep the spike open pending explicit closure authorization.
## Ready for Human QA
- Verify one specifically approved comment send, author, rendered text, discussion association, and API permalink in Slack. If Slack normalizes text, inspect any `PARTIAL` result before considering a retry.
## Done
- Inspect CLI, official APIs, existing identity/scopes, and supplied discussion read-only. Verified user identity, available scopes, root association, three existing replies, and real API permalink. Item metadata lacks a thread locator.
- Add bounded List item comments read/post commands with dry-run-first behavior, target/identity checks, readback, and API permalinks. `lists comments` and `lists comment` require a copied existing comment URL and refuse mismatched or missing root metadata. Partial/uncertain sends are surfaced without automatic retries.
- Add offline tests and maintained CLI/skill documentation. Test commands: `python3 lifeos-tools/tests/test-slack-comments.py` and `bash lifeos-tools/tests/test-slack.sh`; both pass (11 new unittest cases plus existing Slack regression checks). The new read command also passed against the supplied live discussion and returned its API root permalink. A bounded scan found no invalidated vault skill assumptions. New tests use invented IDs and text only.
## Remaining API limitation
The observed public API does not resolve a discussion or create its first comment from List/record IDs alone. Existing-discussion posting uses the documented chat reply mechanism but remains live-unverified. No credentials or scopes were changed.
