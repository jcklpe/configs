---
name: log-kaizen
description: "Record a private Kaizen incident when the user asks to log workflow feedback, a consequential agent failure occurs, or a repeated mismatch needs evidence. Capture the event and immediate correction without treating the incident as permission to change standing rules."
---

# Log Kaizen
## Scope and authority
Capture consequential workflow incidents and update their private evidence links. Logging does not itself improve the workflow. Review and intervention design belong to `improve-agent-workflows` when available, but that companion is not required to record an incident.

Follow project authority and the user's request. Capture may be activated by existing instructions without another permission request. Honor discussion-only, read-only, and no-save boundaries. Ordinary artifact repairs remain governed by the task's authorization. An incident, recurrence, or candidate explanation never authorizes changes to standing skills, policies, prompts, or operating rules; already-authorized changes need no second approval.

## Private destination contract
Choose the store by the owner of the affected guidance, not just the working directory. Project-specific incidents use the project's declared private store. Global reusable-skill or global agent-behavior incidents use the configured private global store. Keep one authoritative incident; cross-reference privately when both scopes matter rather than copying a narrative into a wider audience.

For global local-file access, resolve one complete configuration source in this order:
1. An explicitly selected `KAIZEN_ENV_FILE`; otherwise this skill folder's adjacent `.env` when present.
2. For existing installations only, the JSON file selected by `KAIZEN_CONFIG`; otherwise `kaizen/locations.json` under `XDG_CONFIG_HOME`, or the user's `.config` directory when unset.

The env file contains `KAIZEN_GLOBAL_CURRENT` and `KAIZEN_GLOBAL_INCIDENTS`, both absolute paths to designated private Markdown records. Copy `.env.example` only when setting up a configuration; actual values stay in the ignored `.env`. Parse literal `KEY=VALUE` lines with optional matching quotes and comments on their own lines. Never source or execute the file, expand shell substitutions, or print its values into public output. Legacy JSON is `{"global":{"current":"<absolute private path>","incidents":"<absolute private path>"}}`. Do not combine partial values from different sources. An explicitly selected, present-but-invalid, or inaccessible configuration is an access gap, not a reason to silently use another store. Both Kaizen skills use this data contract; they may share an explicitly selected env file or independently point to the same records.

For connector-only work, use the exact private documents designated by the user or project. Local paths do not establish connector access. Confirm the destination, follow symlinks to actual files, and check repository/sharing context. A name, pointer, or ignore rule alone does not establish privacy. Neither the public skill folder nor a public scratch file is a log destination.

If the store is absent, ambiguous, or inaccessible, report that capture was not completed and continue independent work. Keep a proposed record only in the current authorized conversation. Never create a public fallback or guess a same-named remote document.

## Capture procedure
1. Establish the observed mismatch and expected behavior from actual instructions or user evidence. Separate an existing expectation from a newly expressed preference. Do not log every typo, disagreement, ordinary product idea, or uncertain impression as a failure. Explicitly requested useful observations may be captured as observations.
2. Read the relevant concern and existing incident before appending. Avoid unrelated history. Update the same event rather than duplicating it; a later occurrence is new evidence linked to the existing concern.
3. Use a dated descriptive heading with a stable return point. Distinguish event date from capture date if different. Include what happened, the expectation and its source, affected workflow, relevant evidence, model/configuration only when known and useful, immediate correction, and verification limits. Unknown facts stay unknown; label hypotheses as inferences.
4. Include only context needed to understand the mismatch. Exclude credentials, unrelated personal details, wholesale transcripts, and unnecessary private material. Keep incidents out of public commits, examples, issues, and shared reports.
5. Re-read shared files immediately before writing, preserve intervening edits, and use revision guards when supported. Add dated follow-up evidence rather than silently rewriting what was known. Correct factual or privacy errors transparently without retaining material that should not be stored.
6. Link to an existing concern or add a concise concern when continued analysis is warranted. An isolated repaired incident need not become a lasting task. Use evidence-based states such as needs analysis, change implemented; effectiveness untested, or no further action. Never mark a proposed intervention approved.
7. Briefly report what was captured and any access or verification gap. Acknowledge capture at a safe boundary without interrupting authorized work with repeated confirmation requests.

## Record contract and boundaries
Maintain two working Markdown records: current concerns and incident evidence. Concerns link to incident headings and distinguish observation, proposal, user approval, implementation, and outcome. No rigid form is required; preserve the store's established headings, metadata, and wording.

Logging does not install background monitoring or guarantee detection. A corrected artifact or successful run is evidence about that instance, not proof of prevention. Retention review and intervention proposals belong to review work, not automatic side effects of capture.
