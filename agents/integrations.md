# Restoring agent integrations
Use the service-owned setup guides below when restoring this installation. These are the direct integrations observed in local client configuration on 2026-10-26, not a list of suggested MCPs. No client settings, credentials, or account bindings are exported here, and no live service checks were performed for this inventory.

| Direct MCP | Configured clients | Restore procedure and remaining verification |
| --- | --- | --- |
| Penpot | Codex, Claude Code | [setup-penpot](../agent-hands/skills/setup-penpot/SKILL.md), then [use-penpot](../agent-hands/skills/use-penpot/SKILL.md). Recreate the ignored server URL locally, register the connector, and verify a read from a user-connected design file. Tool discovery alone does not validate its key. |
| Pencil | Codex, Claude Code | [setup-pencil](../agent-hands/skills/setup-pencil/SKILL.md). The installed VS Code extension owns its server and client integration. Executable presence was confirmed; connected-document access and fresh-account setup were not. |
| JASP | Codex | [setup-jasp](../agent-hands/skills/setup-jasp/SKILL.md). Restore the pinned bridge configuration and a JASP build with local RPC enabled. The required application build/enablement procedure and a successful RPC check remain unverified. |

## Client plugins and runtime tools
GitHub, Google Drive, Gmail, Google Calendar, and Notion were enabled Codex service-plugin selections. Restore only the selected plugins through the client's own plugin interface, complete their account connection flow, then verify a bounded authorized read. Their backends are not established to be the vendors' separately advertised MCP endpoints. CLI account configuration is separate. Earlier installed-directory entries for other services are not sufficient evidence to prescribe them for a new machine.

`node_repl` was a configured client runtime entry, and a `computer-use` entry was explicitly disabled. Restore client-managed features through that client's supported installation; no standalone package or portable executable path was established for these internal entries. Do not enable the disabled server as a side effect of restoration.

The [skill symlink installer](../install-script/functions/symlinks.sh) installs selected skill links, not MCP servers or account connections. These setup guides can be read directly from the checkout; this documentation change does not register new clients, install global skills, or prove fresh-session discovery. Keep server installation, client registration, authentication, and successful use as separate checks.
