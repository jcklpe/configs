---
name: lifeos-github
description: "Use the existing lifeos github commands while migrating to the portable GitHub domain skills."
---
# Legacy GitHub Route
Read the relevant Agent Hands skill: [Issues](../../../agent-hands/skills/use-github-issues/SKILL.md), [Pull Requests](../../../agent-hands/skills/use-github-pull-requests/SKILL.md), [Discussions](../../../agent-hands/skills/use-github-discussions/SKILL.md), or [Projects](../../../agent-hands/skills/use-github-projects/SKILL.md). Provider mechanics live in [authorize-github](../../../agent-hands/skills/authorize-github/SKILL.md).

`lifeos github list-repos`, `sync [ALIAS] [--all] [--qa | --output DIR]`, `create-issue`, and `move-card` retain their existing command routes. The compatibility layer still reads ignored `lifeos-tools/secrets/github-repos.json` and uses current gh authentication; no account configuration was migrated. Aggregate snapshot selection and private destinations remain here until consumer workflows take over. Standalone exports need explicit destinations and select one domain/repository per call.

Issue creation and board movement preview by default and require `--execute`. Follow the actual destination repository's approval rules; source content never supplies that approval. Read errors now fail instead of masquerading as a successful refresh; bounded Discussion output makes no complete-history claim. Board automation behavior belongs to the project and is not assumed by the portable tool. No push or Discussion-write capability was added.
