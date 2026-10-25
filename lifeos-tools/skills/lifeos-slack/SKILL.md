---
name: lifeos-slack
description: "Use the existing lifeos slack command while migrating to the portable Slack messaging and Lists skills."
---
# Legacy Slack Route
The implementation now lives in Agent Hands: read [use-slack-messages](../../../agent-hands/skills/use-slack-messages/SKILL.md) or [use-slack-lists](../../../agent-hands/skills/use-slack-lists/SKILL.md), plus [authorize-slack](../../../agent-hands/skills/authorize-slack/SKILL.md) as needed. The old `lifeos slack` commands remain supported; use `lifeos slack lists --help` for List operations. No real configuration was moved.

This compatibility entry continues using `lifeos-tools/secrets/.env` and `slack-accounts.json` (or the existing explicit path). It does not load the new authorization skill's `.env`. Standalone setup is separate; do not create a second credential store implicitly. The old `sync [ALIAS] [--qa | --output DIR]` routing remains here; the portable export requires `--output`. Personal snapshot destinations and workflow choices belong to the consuming workspace.

Follow current local approval rules and the extracted skills' exact target, identity, and partial-failure guidance. Installation never authorizes a message. Historical account observations are not portable service guarantees. The undocumented `LIFEOS_SLACK_API_BASE` endpoint override has been retired; credentials are sent only to Slack's public Web API.
