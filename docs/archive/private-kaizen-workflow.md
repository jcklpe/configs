---
attention: historical
---
# Private Kaizen Workflow
Opened: 2026-10-13
Spike: private-kaizen-workflow
Closed: 2026-10-13
Status: closed at the user’s direction after implementation review.

Historical record at closure. Use the [maintained owners](#maintained-owners) for current guidance; this pair preserves the reasoning and implementation evidence.

## Purpose
Replace a public, manually invoked skill-feedback intake with a private incident-learning loop that agents operate during ordinary work. The user should not have to remember to log, search, or triage incidents. The name Kaizen and the narrow incident framing have proved easier for the user to invoke than general skill feedback.

## Approved Design
Agents may capture incidents, connect evidence, label hypotheses, maintain current concerns, and prepare proposals. Only the user may authorize changes to standing skills, policies, prompts, or operating rules. Logging, recurrence, review, and an agent's proposed explanation are never substitutes for that authorization. Existing approval covers its actual scope without a repeated permission ceremony.

Keep a maintained current-concerns file separate from a dated incident record. Repairing an immediate output, changing an instruction, and observing later behavior are distinct outcomes. Remove handled concerns from active attention without deleting the evidence or declaring a wording change proven effective. Maintain an observation section for interventions whose effect is not yet established.

Keep the reusable workflow public and the incident records private. Global skill concerns use a privately configured store outside the public repository. A private project keeps its own store for project-specific workflows; the owning instruction determines routing, not the project in which the incident happened. Do not duplicate full incidents across stores. Project evidence crosses into a reusable public change only through deliberately selected, approved instructions or examples.

Consult relevant current concerns at the beginning of substantial workflow use and skill revisions, on consequential corrections, and during an existing periodic review. A bounded retrospective pass catches otherwise unattended concerns without displacing the substance of the retrospective or turning every incident into a proposal.

## Implementation Choices
Use one portable `kaizen` skill with a vendored copy where the private project's agents need it. Preserve the old `log-skills-feedback` name as a compatibility redirect, with no separate capture method or public fallback. A private configuration supplies global record locations; repository instructions supply declared private project locations. Missing access must be reported rather than silently substituting a public file.

Retain the private project's existing incident filename and anchors, adding a current-concerns index beside it. Migrate the public feedback entries verbatim into private evidence, explicitly identified as legacy feedback rather than newly verified incidents. Leave a retirement notice at the public path for historical links; stop installing public-log shortcuts. Prior Git history is not erased by this migration, and a history rewrite or remote publication is outside scope.

Use review-time rotation for old incident material, preserving evidence and links in dated private archives. No scheduled service, automatic deletion, or universal recurrence threshold is introduced. Default rotation guidance is twelve months, subject to local move permissions; unresolved evidence remains reachable. A record is normally additive but factual and privacy corrections are allowed and attributed.

## Boundaries and Evidence
This is a new spike, separate from the completed project-workflow refinement. Its read-only exercise demonstrated little about real execution. Validate this implementation through destination resolution, preservation, privacy boundaries, reference checks, and installer behavior. Do not describe instruction changes or scenario inspection as proof that agents will follow the loop in real use.

No changes to unrelated tools or historical incidents' proposed target skills are authorized merely by their migration. No pushes or public-history rewrites. Preserve unrelated working-tree changes and repository commit cadence.

## Implementation and Verification — 2026-10-13
The portable workflow, global activation instructions, private global stores and location configuration, legacy redirect, and selective shortcut retirement are installed. A private project vendors the same workflow body with native metadata and keeps its own existing incident record plus a new current-concerns index. Its retrospective reviews the two stores separately when accessible, keeps process analysis out of the main life narrative, and requires explicit approval for proposed standing-rule changes.

All seven former public feedback entries were preserved verbatim in private evidence before replacing the public intake with a notice. Eight existing private project incident bodies and anchors were retained. Migration review distinguished implemented core instruction changes from remaining analysis without assuming that old proposals were approved or that wording changes established effectiveness. No historical remote action was replayed.

Verification covered private location resolution and file permissions, outside-repository global storage, preservation comparisons, installed links, global skill validation, native metadata and matching workflow bodies, new relative links and anchors, public added-text review, and isolated bash/zsh tests of the installer changes including idempotence and preservation of unrelated links/files. Syntax and whitespace checks pass. This verifies the installed structure and narrowly tested operations; ordinary agent capture, retrieval, proposal discipline, and retrospective use remain to be observed. Connector access was not exercised. No background scheduler or automatic deletion was installed.

The source repository receives a scoped local checkpoint. The private project's daily cadence is already satisfied; its changes remain alongside unrelated ongoing work rather than being swept into this source commit. No push or public-history rewrite occurred. The user subsequently reviewed the implementation and authorized closure on 2026-10-13. Ordinary-use behavior and connector access remain unproven by these checks; future incidents and proposals belong in Kaizen rather than keeping this implementation spike open. No successor implementation is required for closure.

## Maintained Owners
- [Kaizen skill](../../skills/kaizen/SKILL.md): workflow, privacy, proposal and approval boundary.
- [Global instructions](../../agents/AGENTS.global.md): standing activation during ordinary work.
- [Write skills](../../skills/write-skills/SKILL.md): consult evidence before an authorized skill change.
- [Installer](../../install-script/functions/symlinks.sh): discoverable global skill and retirement of old log shortcuts.
- Private project instructions and retrospective: local routing and bounded recurring review; private records are not copied into this development history.

Continues from: docs/archive/project-workflow-refinement.md
