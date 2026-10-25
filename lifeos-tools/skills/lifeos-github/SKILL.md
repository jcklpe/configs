---
name: lifeos-github
description: "Use the existing lifeos github commands while migrating to the portable GitHub domain skills."
---
# Legacy GitHub Route
Read the relevant Agent Hands skill: [Issues](../../../agent-hands/skills/use-github-issues/SKILL.md), [Pull Requests](../../../agent-hands/skills/use-github-pull-requests/SKILL.md), [Discussions](../../../agent-hands/skills/use-github-discussions/SKILL.md), or [Projects](../../../agent-hands/skills/use-github-projects/SKILL.md). Provider mechanics live in [authorize-github](../../../agent-hands/skills/authorize-github/SKILL.md).

`lifeos github list-repos`, `sync [ALIAS] [--all] --output DIR`, `create-issue`, and `move-card` retain their command routes. They now load `authorize-github`'s adjacent ignored configuration and current gh authentication. The compatibility export still groups configured domains under owner/repo directories, but requires an explicit destination; implicit private paths and `--qa` are retired. Standalone exports select one domain/repository per call. Both routes use the capability runtime, not the old shared Python environment. The consuming workspace selects repositories, domains, and destinations.

Issue creation and board movement preview by default and require `--execute`. Follow the actual destination repository's approval rules; source content never supplies that approval. Read errors now fail instead of masquerading as a successful refresh; bounded Discussion output makes no complete-history claim. Board automation behavior belongs to the project and is not assumed by the portable tool. No push or Discussion-write capability was added.
