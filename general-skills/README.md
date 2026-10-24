# General Skills
Reusable procedures that are available independently of a project's operating package. Source placement does not automatically install every skill globally or make it a dependency of adopting projects.

| Skill | Purpose | Installation state |
| --- | --- | --- |
| [track-changes](track-changes/SKILL.md) | Review Markdown using the locally adapted Obsidian Track Changes workflow. | Existing Codex/Claude access retained; upstream provenance travels with the folder. |
| [write-skills](write-skills/SKILL.md) | Author and revise scoped, portable skills. | Existing Codex/Claude access retained. |
| [update-derived-skills](update-derived-skills/SKILL.md) | Reconcile an upstream-derived skill while preserving intentional adaptations. | Available by reading this skill; not added to the default global installation list. |

The installer now points the existing review/authoring links directly here. Temporary links at `skills/track-changes` and `skills/write-skills` preserve previously installed client links and existing source references during migration. They contain no duplicate skill implementation. Remove them only after the dependent installations and live references have been repointed.

`operate-lifeos`, `log-kaizen`, and `improve-agent-workflows` also belong in this collection under the agreed architecture, but their migrations have not happened yet. The current handoff and Kaizen procedures remain in their existing locations. Project workflow seeds remain under `skills/`, and CLI service skills remain under `lifeos-tools/skills/` until their separate extraction slices are ready.

See the [modular distribution spike](../docs/active-spikes/modular-skill-distribution.md) for the current implementation state and remaining decisions.
