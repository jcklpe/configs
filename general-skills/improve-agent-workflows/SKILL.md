---
name: improve-agent-workflows
description: "Review Kaizen evidence when preparing substantial workflow or skill changes, investigating recurring agent failures, or conducting a periodic workflow review. Reconcile incidents with current implementation, propose focused improvements, and apply only changes authorized by the user."
---

# Improve Agent Workflows
## Scope and authority
Use private Kaizen evidence to prepare better workflows and evaluate authorized interventions. During preparation, inspect relevant current concerns and use the evidence for checks within the task's approved scope; do not turn preparation into an unsolicited redesign.

Agents may review evidence, label hypotheses, maintain private concerns, and prepare proposals. Only the user's explicit go-ahead authorizes changes to standing skills, policies, instructions, prompts, or operating rules. A recurrence, log entry, review request, or earlier agent recommendation is not that permission. Honor approval already covering the work; do not ask again merely because a change touches a skill. Discussion-only, read-only, and no-save instructions constrain record maintenance as well as implementation.

## Private destination contract
Use the affected guidance's owner to select scope: project-specific incidents use its declared private store, while global reusable-skill and global agent-behavior incidents use the private global store. Keep one authoritative narrative and private cross-references where scopes overlap.

For global local-file access, use an explicitly selected `KAIZEN_ENV_FILE`, otherwise this skill's adjacent `.env` when present. Both `KAIZEN_GLOBAL_CURRENT` and `KAIZEN_GLOBAL_INCIDENTS` must name absolute paths to designated private Markdown records. The adjacent `.env.example` defines the keys; actual values remain ignored. Parse literal `KEY=VALUE` data with optional matching quotes and comments on their own lines; never source or execute it, expand shell substitutions, or print its values into public output.

If no env configuration was selected or present, preserve existing installations through `KAIZEN_CONFIG`, or `kaizen/locations.json` under `XDG_CONFIG_HOME` (the user's `.config` directory when unset). Legacy JSON is `{"global":{"current":"<absolute private path>","incidents":"<absolute private path>"}}`. Use one complete source. An explicitly selected, present-but-invalid, or inaccessible configuration is an access gap, not permission to silently fall back. This is the same data contract as `log-kaizen`; neither procedure requires loading the other. They may share an explicitly selected env file or independently reference the same records.

Connector-only contexts use exact private documents designated by the user/project. A local path or similarly named search result does not establish access. Follow links to actual files and verify repository/sharing context; being ignored or named Kaizen is insufficient. If the destination is missing or inaccessible, report the gap and continue independent work. Never create a public fallback, copy private evidence into public examples/commits, or invent a destination.

## Review and intervention procedure
1. Read the relevant current concerns and linked incidents. During focused preparation, avoid the entire history. During periodic review, briefly check older pending concerns so inactive workflows are not forgotten.
2. Separate observation, expectation, hypothesis, user decision, and agent proposal. Verify what was implemented against current owning files. A proposed patch in a log is not proof of a change; an old diagnosis may be stale.
3. Identify the smallest useful intervention. Consider tooling, verification, access, or process changes as well as instructions; adding prose is not the automatic remedy for failing to follow prose. Do not invent recurrence thresholds or convert unrelated brainstorming into incidents.
4. Prepare a concrete private proposal: observed problem and bounded evidence, exact owning files, current → proposed wording or patch, why it may help, and an appropriate later check. For a batch, use the user's approval-slate convention if available. Approval concerns the proposed change, not an invitation to expand its scope.
5. Apply and verify only authorized changes under the owning project's rules. Do not install, propagate, commit, or publish an unapproved standing-rule change. A general Kaizen review authorizes analysis, not every recommendation; publication remains separately governed.
6. Maintain the private concern with review date/scope, access gaps, actual user decision, implementation evidence, and later outcome. Distinguish needs analysis, proposal awaiting approval, change implemented; effectiveness untested, observed after change, and no further action. Do not equate an edit, lack of reports, or one success with reliable prevention.
7. Move handled concerns out of active attention into observation or a linked disposition without losing evidence. If no decision is needed, say so briefly; do not repeatedly present unchanged deferred proposals. New capture can use `log-kaizen` when available or the store's established record convention.

## Retention and completion
Keep current concerns and incidents as separate working records with stable links. During periodic review, consider rotating incident material older than twelve months into dated private archives when useful. Honor local move permissions, copy/verify before removing source entries, preserve original evidence, and repair links. Do not create empty archives, scheduled jobs, or monitoring merely to satisfy this procedure.

Report what was reviewed, proposed, implemented under approval, and observed, with remaining limits. Keep private evidence in its designated store and use only audience-appropriate summaries elsewhere. Changes to this review procedure itself require the same explicit authority as other standing guidance.
