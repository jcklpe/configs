# Agent integrations
The portable [Agent Hands MCP catalog](../agent-hands/mcp-integrations.md) owns service sources, optional setup, capability overlap, and verification limits. This file records this configs checkout's client selections and extras. It is a public-safe inventory, not a copy of live client configuration or an instruction to install every entry.

## Observed selections
Checked 2026-10-24. Local configuration was inspected for integration names/enabled flags only; no endpoint arguments, headers, credentials, account identities, or project bindings are reproduced here. Saved entries, installed plugins, currently exposed tools, and authenticated access are different states.

| Client surface | Observed entries | Evidence and limit |
| --- | --- | --- |
| Codex named MCP configuration | `computer-use`, `jasp`, `node_repl`, `pencil` | Names present in user configuration. This does not establish a healthy server, public installer, or current availability for each entry. Do not copy machine-specific executable paths into the repository. |
| Codex service-plugin selections | GitHub, Google Drive, Gmail, Google Calendar, Notion | Enabled in local plugin configuration. Their setup sources and service distinctions belong in the portable catalog. |
| Additional service plugins reported installed by the app directory | Google Contacts, Outlook Calendar, Trello, Slack, Figma | Directory metadata confirmed installation during this review. This is not proof of a successful authenticated service call or parity with the vendor server. |
| Codex document/artifact and client extras | Documents, spreadsheets, presentations, PDF, template creator, visualize, Chrome/browser/computer-use integrations, Codex app tools, code review | Enabled local selections. These are client/runtime features or plugins; they are not dependencies of every Agent Hands skill. Use the client's current setup/discovery rather than inventing standalone MCP packages for their internal names. |
| Claude global MCP configuration | `pencil` | Present in the global client configuration. No enabled global plugin entries were found in the inspected settings. Project-specific configurations were not inventoried or changed. |

Other runtime tools may be supplied by managed configuration or connections not represented by these local plugin tables. The list is dated evidence, not a complete inventory of all machines or accounts. It deliberately records no workspace or tenant mappings. Reinspect names and states when updating it; do not paste raw configuration or directory responses into public docs.

## Installing or changing a connection
Use the client's plugin directory for a supported plugin, or the selected vendor's official server setup for a direct MCP connection. These are different routes; avoid duplicate connections until there is a reason for both. Install only the requested capability and preserve existing configuration. Account OAuth setup remains local and separate from CLI provider configuration.

For Codex, [MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli) documents server enablement, `enabled_tools`, `disabled_tools`, and tool approval settings. [Plugin configuration](https://developers.openai.com/plugins/build/plugins) documents the corresponding `plugins.<plugin>.mcp_servers.<server>` policy. Tool names must come from the selected server; an allowlist for one backend is not portable to a similarly named plugin. Check actual discovery after a change. A prompt/approval policy is distinct from provider-level permissions and does not authorize an external action by itself.

The CLI skill installer remains [the explicit symlink list](../install-script/functions/symlinks.sh). MCP connections are not created by those skill links, and this inventory does not change the selected global skill list. No connections, tokens, permissions, or global installations were changed while writing it.
