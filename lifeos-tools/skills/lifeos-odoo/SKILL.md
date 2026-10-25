---
name: lifeos-odoo
description: "Compatibility route for existing lifeos odoo commands while Odoo moves to the portable use-odoo-projects skill."
---

# LifeOS Odoo Compatibility
The implementation and operation boundaries now belong to [use-odoo-projects](../../../agent-hands/skills/use-odoo-projects/SKILL.md), with [authorize-odoo](../../../agent-hands/skills/authorize-odoo/SKILL.md) provider support. Read the current project's instructions first. New independent users should use the portable setup/use skills.

Existing configured installations may continue calling `lifeos odoo ...` with the same subcommands and flags. In the use skill's examples, substitute that prefix for `bash scripts/odoo`. Both entries now load the authorization skill’s adjacent ignored `.env`, account configuration, and request cooldown state, with the documented provider overrides. The legacy shared env and secret-directory defaults are no longer active. Configuration migration must preserve existing accounts, API keys, and cooldown state; it does not grant new access.

Keep dry-run/execute semantics, bounded target checks, required write readback, and no-delete/no-generic-model limits. A tool move does not authorize a live write or broaden account access. Retire this route only after affected callers and private configuration have deliberately migrated. No credential values or account mappings belong in public records.
