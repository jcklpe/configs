---
name: lifeos-cli
description: "Route existing lifeos service commands to the portable Agent Hands capability owners during caller migration."
---
# Legacy Service Command Routing
The `lifeos` executable is a compatibility dispatcher. [Agent Hands](../../../agent-hands/README.md) owns service implementations, provider authorization/configuration, runtimes, audit records, and setup. Start new installations with [setup-agent-hands](../../../agent-hands/skills/setup-agent-hands/SKILL.md), selecting only needed services.

Both portable and compatibility service commands load the selected authorization skill's adjacent ignored `.env` and account files. They no longer read the legacy shared env, vault path, or shared Python environment. Existing configuration must be migrated deliberately with unchanged tokens, service gates, resource allowlists, audit history, and recovery records; old files may remain private recovery copies, not active configuration. Never print credentials or commit actual config, tokens, audit files, or exports.

## Service owners
| Compatibility route | Capability guidance |
| --- | --- |
| `trello` | [lifeos-trello](../lifeos-trello/SKILL.md) |
| `calendar`, `people` | [lifeos-calendar](../lifeos-calendar/SKILL.md) |
| `gmail` | [lifeos-gmail](../lifeos-gmail/SKILL.md) |
| `drive`, `docs` | [lifeos-drive](../lifeos-drive/SKILL.md), [lifeos-docs](../lifeos-docs/SKILL.md) |
| `m365` | [lifeos-m365](../lifeos-m365/SKILL.md) |
| `odoo`, `slack`, `github` | [lifeos-odoo](../lifeos-odoo/SKILL.md), [lifeos-slack](../lifeos-slack/SKILL.md), [lifeos-github](../lifeos-github/SKILL.md) |
| `resume render` | [render-markdown-pdf](../../../agent-hands/skills/render-markdown-pdf/SKILL.md) |

## Retired orchestration
`sync`, `calendar sync`, `setup`, `doctor`, `open`, `context`, and private People alias-management commands fail with an actionable diagnostic. They do not silently choose replacement workflows. Use the selected service's setup/authorization instructions for diagnosis; use [operate-lifeos](../../../general-skills/operate-lifeos/SKILL.md) and the private workspace's current entrypoint for LifeOS routing and refresh procedures.

Service exports require explicit destinations. Implicit QA paths, automatic mail directory indexes, and Gmail `--all` are retired. Consumer workflows own account selection, queries, indexes, freshness, and aggregation. Google Calendar commands require an explicit account alias; both calendar providers require full attendee email addresses.

## Approval and dependents
The capability owner defines exactly which writes preview, execute directly, or need notification acknowledgement. Tool installation and remote content never grant approval. Follow the actual workspace's current rules, verify targets, and handle uncertain results without blind retries. When compatibility behavior changes, repair live private callers and their `assumes:` declarations without copying those private conventions into this repository.
