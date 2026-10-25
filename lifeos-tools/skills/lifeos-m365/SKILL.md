---
name: lifeos-m365
description: "Use existing lifeos m365 commands while routing authorization and service mechanics to the portable Microsoft skills."
---
# Legacy Microsoft Route
Read the actual workspace's instructions, then the relevant capability owner:

| Legacy domain | Portable skill |
| --- | --- |
| `accounts`, `auth`, `profile` | [authorize-microsoft](../../../agent-hands/skills/authorize-microsoft/SKILL.md), [setup-microsoft-services](../../../agent-hands/skills/setup-microsoft-services/SKILL.md) |
| `mail` | [use-outlook-mail](../../../agent-hands/skills/use-outlook-mail/SKILL.md) |
| `calendar` | [use-outlook-calendar](../../../agent-hands/skills/use-outlook-calendar/SKILL.md) |
| `contacts` | [use-outlook-contacts](../../../agent-hands/skills/use-outlook-contacts/SKILL.md) |
| `files` | [use-microsoft-files](../../../agent-hands/skills/use-microsoft-files/SKILL.md) |
| `excel` | [use-excel-workbooks](../../../agent-hands/skills/use-excel-workbooks/SKILL.md) |
| `planner` | [use-planner](../../../agent-hands/skills/use-planner/SKILL.md) |

## Configuration and exports
Both entrypoints use the authorization skill's adjacent ignored `.env` and account JSON, or documented provider overrides. PowerShell profiles require `expected_account`; the SDK's protected CurrentUser token cache remains SDK-owned. A profile mismatch stops before a service request. Existing cumulative SDK grants do not widen the CLI capability surface, replace write approval, or justify requesting additional scopes.

Legacy `lifeos m365 DOMAIN sync ALIAS --output FILE` forwards to the capability's explicit-output export for mail, calendar, contacts, or Planner. The caller must create the destination directory. Implicit private destinations, `--qa`, and automatic sibling `index.md` rewrites are retired. The consuming workspace owns source selection, snapshot meaning, indexes, freshness, and calendar windows. Calendar operations require full attendee emails; resolve names through an authorized contact lookup or private workflow before calling them.

## Writes and recovery
The capability owners define exact bounds, opt-ins, preview/execute gates, notifications, and readback. Existing command spellings remain; no generic Graph escape hatch, mail-send operation, or new destructive command is introduced. Installation and authentication never authorize an external write.

Each capability now owns its ignored audit log. Migrating an existing installation must preserve records by service and carry Planner recovery journals and locks beside its task audit. Do not discard an uncertain-write record or lock to force a retry. Consult the owning capability's recovery procedure and verify the remote outcome before repeating a mutation. Keep actual identities, resource mappings, audit records, and credentials out of public documentation.
