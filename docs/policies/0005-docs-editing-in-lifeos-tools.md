# 0005 Google Docs Editing Uses Agent Hands (Duplicated From The Org Repo)
## Current Approach
Maintain Google Docs mechanics in `agent-hands/skills/use-google-docs/`, with authorization in `authorize-google/`. The optional `lifeos docs read` / `lifeos docs replace-once` spellings route through `agent-hands/compat/lifeos/`. It preserves the safety model: dry-run by default, `--execute` to write, exact unique match, revision guard, `--link` support.

- General-purpose Google Docs editing is available through LifeOS without requiring an Open Austin checkout. General-purpose GitHub sync, issue creation, and board moves are also available through `lifeos github`; existing-issue edits use `gh` under the consuming repository's approval rules. Open Austin-specific workflows remain in the org repository.
- The org repo keeps its own copy of the docs tool so it stays self-contained when pulled down standalone. The resulting small code duplication is an **accepted cost**.
- **The org repo must not reference lifeos or personal tooling.** It is a shared repo that others pull down; its agents must get up to speed with no external context. Keep this general-tooling boundary documented in `configs/`; the org repository remains self-contained.

Actual edits remain owned by the consuming workflow's approval rules (`draft-approval-slate`, `process-weekly-meeting`); this policy is about discoverability and generality of the capability, not loosening approval.

## Rationale
Google Docs editing is a general capability. Requiring an organization-specific checkout for every Doc edit hides that capability from unrelated workflows. Small duplication lets the org repository remain independently usable while general LifeOS workflows use their own account aliases and approval rules.

## Links
- [Google Docs skill](../../agent-hands/compat/lifeos/skills/lifeos-docs/SKILL.md)
- [GitHub skill](../../agent-hands/compat/lifeos/skills/lifeos-github/SKILL.md)
- [Docs editing history](../archive/lifeos-docs-editing.md)
- [GitHub tooling history](../archive/lifeos-github-sync.md)
