# General Skills
Reusable procedures that are available independently of a project's operating package. Source placement does not automatically install every skill globally or make it a dependency of adopting projects.

| Skill | Purpose | Installation state |
| --- | --- | --- |
| [track-changes](track-changes/SKILL.md) | Review Markdown using the locally adapted Obsidian Track Changes workflow. | Existing Codex/Claude access retained; upstream provenance travels with the folder. |
| [write-skills](write-skills/SKILL.md) | Author and revise scoped, portable skills. | Existing Codex/Claude access retained. |
| [update-derived-skills](update-derived-skills/SKILL.md) | Reconcile an upstream-derived skill while preserving intentional adaptations. | Available by reading this skill; not added to the default global installation list. |
| [log-kaizen](log-kaizen/SKILL.md) | Capture private incidents and immediate evidence. | Replaces the capture portion of the existing global Kaizen installation. |
| [improve-agent-workflows](improve-agent-workflows/SKILL.md) | Review evidence, propose improvements, and apply authorized changes. | Replaces the review portion of the existing global Kaizen installation. |

The installer now points the existing review/authoring links directly here. Temporary links at `skills/track-changes` and `skills/write-skills` preserve previously installed client links and existing source references during migration. They contain no duplicate skill implementation. Remove them only after the dependent installations and live references have been repointed.

The two Kaizen skills share a private-record data contract, not a required code or skill dependency. Each has a tailored `.env.example` and ignore rules. Existing JSON configuration remains readable during migration; real configuration and incident records are never distributed. The old `skills/kaizen` source route temporarily preserves private links; the `log-skills-feedback` compatibility entry is removed.

`operate-lifeos` also belongs in this collection under the agreed architecture, but its migration has not happened yet. The current handoff remains in its existing location. Project workflow seeds remain under `skills/`, and CLI service skills remain under `lifeos-tools/skills/` until their separate extraction slices are ready.

See the [modular distribution spike](../docs/active-spikes/modular-skill-distribution.md) for the current implementation state and remaining decisions.
