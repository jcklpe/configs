---
name: lifeos-trello
description: "Use the existing lifeos trello command while migrating to the portable Trello capability."
---
# Legacy Trello Route
Read [use-trello](../../../agent-hands/skills/use-trello/SKILL.md) for operations, target checks, and direct-write/partial-failure behavior. [authorize-trello](../../../agent-hands/skills/authorize-trello/SKILL.md) owns portable credential mechanics. Existing `lifeos trello` commands keep the old ignored env configuration; no credential files were moved or copied.

Compatibility keeps `sync [--qa | --output FILE]` and its existing private workspace destination. Standalone `export` requires an explicit output path. The legacy `snooze` spelling remains, but its implicit private list is retired: supply `--list` or an explicit `TRELLO_SNOOZE_DEFAULT_LIST`. Both routes use the portable `schedule-card` operation. Render warnings for cards lacking a start date apply only to caller-configured `TRELLO_SNOOZE_LISTS`; there is no implicit list name. Consumers own their task boundaries, labels, start-date automation, and snapshot policies. Follow the actual workspace's current instructions for those choices.

Trello writes act immediately; they are not dry runs. Bidirectional linking is sequential and can partially succeed. After a successor is created, recover using its existing `--to` reference, never by repeating `--create`. Export now returns failure and preserves the previous snapshot if any board/comment retrieval or rendering step fails.
