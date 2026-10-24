---
name: operate-lifeos
description: "Enter a configured private LifeOS workspace when the user requests LifeOS work, a project handoff, a progress update, or accomplishment logging. Locate its current instructions and follow the vault-owned workflow without copying private conventions into public projects."
---

# Operate LifeOS
## Scope
This is an entry point, not a copy of the private workspace's policies or workflows. Use it only when the user requests LifeOS work or an applicable project instruction explicitly routes the current task there. Do not offer unsolicited handoffs, log accomplishments autonomously, or make LifeOS a dependency of an unrelated code project.

The current request and target project's instructions remain authoritative within their scope. This skill grants no filesystem, connector, credential, or external-write permissions. Installation does not enable background sync or monitoring.

## Find the designated workspace
Use an explicitly supplied workspace/context pointer first. Otherwise read `LIFEOS_ENTRY_CONFIG` when set, or this skill folder's adjacent `.env`. The optional override selects a file, not a command. Parse literal `KEY=VALUE` lines with optional matching quotes and comments on their own lines; never source/execute the file or expand shell substitutions. Do not load a CLI's credential files to discover this workspace.

The adjacent `.env.example` defines the contract:
- `LIFEOS_ROOT`: absolute path to the intended private workspace.
- `LIFEOS_ENTRYPOINT`: path relative to that root; defaults to `AGENTS.md` when omitted.
- `LIFEOS_HANDOFF_INSTRUCTIONS`: optional relative path to the workspace's handoff procedure.

Resolve relative paths against the configured root, not the caller's working directory. Follow symlinks and verify that the selected entry/procedure stays within the intended workspace; a path escaping it requires an explicitly designated external reference. Missing, blank-required, invalid, or inaccessible configuration is an access gap. Do not search the whole filesystem or guess a vault from its name. Keep actual pointers in ignored local configuration; do not print them into public artifacts or commit messages.

For connector-only access, use exact context links designated by the user/project through an already authorized read route. A local pointer does not establish connector access. Do not install a connector, change scopes, or search unrelated private material just to make onboarding succeed.

## Enter only as far as the task requires
1. Read the actual entry document, then the applicable role and task procedure it names. A filename or search snippet is not a substitute. The vault owns its conventions, task routing, storage boundaries, and current context.
2. Distinguish private evidence and proposals from active instructions. Read only relevant context; do not copy private workflow details into public repository guidance to make the next invocation convenient.
3. For a requested project handoff, read the configured handoff procedure when supplied, or discover its owner through the entry document. Preserve truthful attribution, evidence, uncertainty, and the difference between agent execution and human judgment. A request for a report produces a report; it does not by itself authorize writing to the vault or sending it elsewhere.
4. For explicitly requested vault changes, follow its owning procedure and existing approval scope, use available tools, and verify the saved result. A public wrapper cannot override the vault's editing or external-action boundaries.
5. Report what was read, prepared, saved, or left incomplete without exposing unrelated private material. If access is unavailable, continue only supported independent work. For a handoff request, a factual in-chat summary can still be useful, but label the unavailable private format/context rather than claiming integration.

## Dependencies and configuration
Requires a supported read route to the designated workspace, not a particular CLI, global credential layout, service skill, or project-workflow package. Keep authentication and executable service tools outside the vault. Configure only location pointers here; personal context and reporting conventions remain with their private owners.
