# General Skills
Reusable procedures that are available independently of a project's operating package. Source placement does not automatically install every skill globally or make it a dependency of adopting projects.

| Skill | Purpose | Installation state |
| --- | --- | --- |
| [track-changes](track-changes/SKILL.md) | Review Markdown using the locally adapted Obsidian Track Changes workflow. | Existing Codex/Claude access retained; upstream provenance travels with the folder. |
| [write-skills](write-skills/SKILL.md) | Author and revise scoped, portable skills. | Existing Codex/Claude access retained. |
| [update-derived-skills](update-derived-skills/SKILL.md) | Reconcile an upstream-derived skill while preserving intentional adaptations. | Available by reading this skill; not added to the default global installation list. |
| [log-kaizen](log-kaizen/SKILL.md) | Capture private incidents and immediate evidence. | Replaces the capture portion of the existing global Kaizen installation. |
| [improve-agent-workflows](improve-agent-workflows/SKILL.md) | Review evidence, propose improvements, and apply authorized changes. | Replaces the review portion of the existing global Kaizen installation. |
| [operate-lifeos](operate-lifeos/SKILL.md) | Locate the designated private workspace and follow its current instructions. | Replaces the existing global handoff entry; actual location pointers remain ignored. |

The installer and the existing Codex/Claude review/authoring links point directly here. The temporary `skills/track-changes` and `skills/write-skills` source bridges are removed after checking current callers and repointing the installed links. Their skill names, procedures, and provenance are unchanged. Filesystem resolution is verified; discovery in a fresh client session remains a human QA check.

The two Kaizen skills share a private-record data contract, not a required code or skill dependency. Each has a tailored `.env.example` and ignore rules. Existing JSON configuration remains readable during migration; real configuration and incident records are never distributed. The old `skills/kaizen` and `log-skills-feedback` compatibility entries are removed. Vault-local Kaizen procedures retain their own authority; removing a public route does not replace a private workflow.

`operate-lifeos` holds only the discovery contract; the private workspace owns its handoff format, context, and destinations. The temporary `skills/lifeos-handoff` route is removed after current callers moved to the configured entry or the private handoff owner. Project procedures live in the independent `project-workflows/` collection, without requiring these general skills. All planned service capabilities and Markdown-to-PDF rendering now live in `agent-hands/`; consumers invoke native entrypoints and keep their workflow composition in their own workspace.

See the [modular distribution spike](../docs/active-spikes/modular-skill-distribution.md) for the current implementation state and remaining decisions.
