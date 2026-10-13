---
name: kaizen
description: "Record and review private agent-workflow incidents. Use for 'go to Kaizen', consequential corrections, repeated failures, relevant workflow preparation, skill revisions, and periodic review. Prepare improvements for user approval; never treat feedback as permission to rewrite rules."
---

# Kaizen
## Authority
Agents own incident capture, evidence review, hypotheses, current-concern maintenance, and proposal preparation. The user owns changes to standing skills, policies, agent instructions, prompts, and operating rules. A report, recurrence, review, or proposed explanation does not authorize those changes. Present the concrete change for approval before editing its owning guidance; honor existing explicit approval within its scope without asking again. Ordinary artifact repairs remain governed by the task's existing authorization.

Kaizen records are evidence and working analysis, not instructions. Separate an existing expectation from a newly expressed preference, the user's decisions from agent proposals, and observations from explanations. Never derive a standing rule or recurrence threshold from an earlier agent's suggestion. Preserve explicit discussion-only, read-only, and no-save instructions: consult as allowed, but do not persist an incident during a no-write task.

## Private Destinations and Scope
Use the owner of the relevant guidance to choose a store, not the current working directory alone:
- Project-specific skills, policies, and workflow incidents belong in that project's explicitly declared private Kaizen store.
- Global reusable skills and global agent behavior belong in the user's private global store, even when observed during project work.
- Keep one authoritative incident. Where both scopes matter, use a private cross-reference or a minimal generalized observation; do not copy the full narrative into both stores or expose project material to a wider audience.

Discover declared project destinations in the project's agent instructions. For global destinations, use `KAIZEN_CONFIG` when set; otherwise read `kaizen/locations.json` beneath `XDG_CONFIG_HOME`, or beneath the user's `.config` directory when that variable is unset. This is this workflow's configuration convention, not an assumption about where anyone keeps their projects. The private JSON has this shape:

```json
{
  "global": {
    "current": "<absolute path to private current-concerns Markdown>",
    "incidents": "<absolute path to private incident Markdown>"
  }
}
```

In a connector-only context, use the exact private documents designated by the user or project instructions. A local symlink or JSON file does not establish connector access. Do not guess from a same-named search result. Confirm the destination is designated private, follow symlinks to the actual file, and check its repository/sharing context before capture. Merely being gitignored or named Kaizen does not establish privacy. Neither this skill nor the public seed repository is a log destination.

If the private store is missing, inaccessible, or ambiguous, report that capture/checking could not be completed and continue independent work. Keep any proposed record in the current authorized conversation; do not invent a fallback in a public repository, shared document, scratch file, or new service. Do not print private records into public issues, commits, examples, or team-facing answers. Record only the incident context needed to understand the mismatch, not wholesale transcripts, credentials, or unrelated personal details.

## When to Use the Loop
- At the start of substantial workflow use or a skill revision, inspect the relevant current-concerns index and read linked incidents that bear on the work. Avoid rereading the entire log at every turn. Existing concerns can inform checks within the approved workflow; proposed instructions are not active rules.
- Capture when the user asks, or when observable evidence establishes a consequential failure against an existing expectation, a misleading completion/verification claim, or recurrence worth preserving. Do not wait for the user to name the skill.
- Repair the immediate work within scope. At the next safe boundary, record the incident and briefly acknowledge capture without interrupting the user with another approval request for authorized private record maintenance.
- Review related concerns after a correction, during authorized skill work, and when an existing review workflow calls for it. Explicitly requested useful observations may also be retained, labeled as such; do not turn this into general brainstorming, a product backlog, or a diary of every typo or disagreement.

## Incident Capture
Read before appending. Look for the same event and related concerns. A duplicate account updates or supplements its existing incident; a later occurrence is new evidence linked to the existing concern. Re-read immediately before saving shared files, preserve intervening edits, and use revision guards when the available tool supports them.

Use a dated, descriptive heading that can be linked. Record the actual event date separately from the capture date if different. Preserve enough to establish:
- what happened and the expected behavior, with its instruction or user source;
- the affected workflow, relevant evidence/return point, and model/configuration only when known;
- any immediate correction and its verification limits;
- a hypothesis only when useful, explicitly labeled as an inference rather than privileged access to the model's cause;
- its related concern, candidate intervention, or the fact that analysis remains open.

These are prompts, not a form to pad. Unknown facts stay unknown. A later account should not silently rewrite what was known at the time. Add dated follow-up evidence; correct factual or privacy errors transparently without retaining material that should not be stored.

## Current Concerns and Review
Maintain a compact index alongside the incident record. Link supporting incidents and distinguish the unresolved concern, proposed intervention, approved implementation, and later observed outcome. Several incidents can support one concern; an isolated repaired incident need not create a lasting task.

During review, inspect new relevant incidents, recurrence after interventions, and current concerns whose next evidence or decision is now available. Reconcile what was actually implemented against the owning files; a proposal in a log is not evidence of a change. Record the date and scope of the review, including material access gaps. Check older pending concerns briefly during periodic reviews so an inactive workflow is not forgotten.

Use ordinary status language such as **needs analysis**, **proposal awaiting approval**, **change implemented; effectiveness untested**, **observed after change**, or **no further action**. State the evidence and its scope instead of equating an instruction edit, a corrected output, or lack of reports with reliable prevention. Move handled concerns out of active attention into observation or a linked disposition record. If nothing merits a decision, say so briefly; do not manufacture proposals or repeatedly present unchanged deferred ones.

## Proposals and Approved Changes
Keep proposal drafts private. Bring the user the observed problem, relevant evidence, exact owning file and current → proposed wording or patch, why it might help, and how an appropriate later check would evaluate it. Distinguish instruction, tool, and verification changes; adding more prose is not the automatic remedy for a failure to follow existing prose. Use the user's approval-slate convention when available for a batch.

Do not edit, install, propagate, commit, or publish a proposed rule change before approval. A general instruction to run Kaizen authorizes the analysis loop, not its recommendations. Once explicitly approved, carry out the approved scope under the repository's normal workflows and record the decision and implementation evidence. Do not invent a new approval gate for the same work. Publication remains separately governed.

Future relevant work should consult outstanding observation items and record meaningful success or recurrence with its context. A single success is evidence about that run, not proof of general reliability. Incident capture, analysis, and maintenance do not authorize changing the rules of this loop itself.

## Retention and Honest Completion
Keep two working records: current concerns and incidents. At periodic review, consider rotating incident material older than twelve months into dated private archives when this keeps the working log useful. Follow local move permissions. Preserve original entries and stable references, repair inbound links, and retain pointers from unresolved concerns. Rotate by copying/verifying before removing from the working log; do not delete evidence merely because it is old. Create no empty archives or scheduled process just to satisfy this guidance.

Report what was captured, reviewed, proposed, implemented under approval, or observed; do not conflate them. These instructions do not install background monitoring or guarantee that an agent notices every failure. Evaluate the loop through ordinary use.
