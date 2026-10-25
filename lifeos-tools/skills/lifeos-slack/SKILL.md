---
name: lifeos-slack
description: "Use the existing lifeos slack command while migrating to the portable Slack messaging and Lists skills."
---
# Legacy Slack Route
The implementation now lives in Agent Hands: read [use-slack-messages](../../../agent-hands/skills/use-slack-messages/SKILL.md) or [use-slack-lists](../../../agent-hands/skills/use-slack-lists/SKILL.md), plus [authorize-slack](../../../agent-hands/skills/authorize-slack/SKILL.md) as needed. The old `lifeos slack` commands remain supported; use `lifeos slack lists --help` for List operations.

Both entries now load `authorize-slack`'s adjacent ignored `.env` and account JSON, or the selected provider overrides. The compatibility command uses the selected capability's uv environment (or explicit `SLACK_PYTHON`), without loading the shared legacy env. `sync [ALIAS] --output DIR` requires a destination; implicit private destinations and `--qa` are retired. Account identity checks, write gates, and configured List selections are unchanged. Consumer workflows own snapshot paths and freshness.

Follow current local approval rules and the extracted skills' exact target, identity, and partial-failure guidance. Installation never authorizes a message. Historical account observations are not portable service guarantees. The undocumented `LIFEOS_SLACK_API_BASE` endpoint override has been retired; credentials are sent only to Slack's public Web API.
