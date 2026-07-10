---
name: run-project-spike
description: "Run and bucket project work in focused spike docs with a conceptual doc, a to-do doc, TODO.md as an index, scratch promotion, human QA tracking, durable handoff notes, active-spikes placement, archival, and continuation links between related phases of work. Use when starting, continuing, promoting, superseding, archiving, or reviewing project work that should leave navigable history."
---

# Run Project Spike
## Local Precedence
If the current repo already has `skills/run-project-spike/SKILL.md`, or a `how-to-spike.md` document, read and follow the repo-local process first. Treat this global skill as fallback seed material.

## Purpose
A spike is not just a checklist. It is a temporary collaboration space for the user and agents to build taste, vocabulary, decisions, and implementation history around a specific theme of work.

Default toward bucketing project work into a spike so work is easy to find, continue, archive, and relate to later phases. Even small or mixed work can live in a miscellaneous spike bucket such as `misc-302` if it is real project work that should leave history.

Only skip spike bucketing for truly throwaway actions that the user clearly does not want recorded, such as answering a quick question or running a one-off command.

## Where Active Work Lives
When the repo uses `docs/active-spikes/`, create and update active spike pairs there:

```text
docs/
  active-spikes/
    topic.md
    topic.todo.md
  scratch/
    misc.md
    misc-1.md
  archive/
  decisions/
```

Do not add a `README.md` to `docs/` or any subfolder of it. `TODO.md` is the index, and a per-folder README will only restate the authority rules that already live in `AGENTS.md`.

The setup skill owns creating this structure. This skill uses the structure once it exists: active conceptual and to-do docs go in `docs/active-spikes/`, rough pre-spike material goes in `docs/scratch/`, and finished or superseded spike history goes in `docs/archive/`. Durable long-term docs stay in `docs/` or another repo-specific location instead of being mixed with active spike work.

If a repo already uses flat active docs directly under `docs/`, preserve that convention unless the user is intentionally migrating the repo to `docs/active-spikes/`.

## Authority Ladder
Respect the repo's own rules first. In this pattern, use docs according to this authority order:

- `AGENTS.md`, `README.md`, and durable project docs are project rules.
- A repo-local `skills/run-project-spike/SKILL.md`, if present, explains this work process.
- Active spike docs explain current thinking for a theme of work.
- Active spike to-do docs track implementation state.
- `TODO.md` is the index of active, recently completed, waiting, and later spikes.
- `docs/scratch/` is non-authoritative working material.
- `docs/archive/` is historical context, not current rules, unless durable docs still agree with it.

## TODO.md Role
Use `TODO.md` as an index and coordination map, not as the place for fiddly implementation detail.

It should point to active spike docs, note waiting-for-human-QA items, list recently completed or archived spikes, and hold lightweight later ideas. Detailed work items, command logs, and state transitions belong in the spike's `.todo.md`.

## The Two Documents
Active spikes use two docs:

- A conceptual doc, such as `docs/active-spikes/<topic>.md`.
- A to-do doc, such as `docs/active-spikes/<topic>.todo.md`.

The conceptual doc explains the work's purpose, philosophy, boundaries, and settled model. It should help a new agent understand what kind of solution would be in character for the project.

The to-do doc tracks concrete atomic tasks for implementation work. It should be operational: files, actions, QA notes, unresolved questions, and what has already happened.

Do not collapse these into one doc when the work needs both mental model and execution tracking. The separation is functional: the conceptual doc preserves taste and constraints; the to-do doc preserves movement and state.

## Conceptual Docs
Use the conceptual doc for:

- goals and non-goals
- project vocabulary
- engineering, design, shell, setup, or product philosophy
- major decisions and why they were made
- relationship to other spikes
- constraints that should shape future work
- safety and privacy boundaries
- continuation links to predecessor or successor spikes

Avoid turning the conceptual doc into a running changelog. When implementation details become durable rules, fold them into longer-lived docs such as `README.md`, `AGENTS.md`, a decision record, a runbook, or another active reference doc.

## To-Do Docs
Use the to-do doc for:

- concrete atomic work items
- current state notes
- implementation progress
- commands and verification steps
- human QA requests
- known edge cases
- short historical notes that will help future agents reconstruct what happened

The to-do doc usually follows this rough shape:

- Background
- Project Organization
- General Principles
- Current State Overview
- To Do
- Ready for Human QA
- Done

Exact headings can flex, but future agents should be able to find current work, QA work, and completed work quickly.

Consider adding sections for:

- public safety, privacy, and secrets
- startup, install, or symlink impact
- environment or OS matrix
- validation commands
- rollback or recovery notes
- whether the work belongs in this public repo or somewhere private

## Moving Work
Work starts in `To Do`.

When an agent finishes implementation but the user needs to visually or manually verify it, move the item to `Ready for Human QA`.

When the user confirms QA, move it to `Done`.

When implementation does not need human QA, move it directly to `Done` after verification.

`Done` is allowed to preserve useful history. It should not be a perfectly compressed final summary. These docs are archived at the end of the spike, and that archive can help future agents understand why the code ended up this way, even if the notes along the way are messy or not totally current. Prefer a useful decision and implementation trail over a neat but context-poor summary. Do not sand off the rough corners of historical artifacts.

### Moving An Item Preserves It
Moving an item is a *move*, not a rewrite. Carry the item's original wording into `Done` and append what happened. Do not restate it in your own words, and do not compress it because you now know how it turned out.

**One `To Do` item becomes exactly one `Done` entry.** Never merge several items into a single synthesized entry, however naturally they were finished together. The plan and the outcome are two different artifacts: the history explains why the code looks like this, and the surviving item list is what lets a reader check the plan against the result. An agent that finished three items in one motion has three `Done` entries, each with its own note.

Unplanned work gets *added* entries — surprises, reversals, things discovered — never folded into a planned item's entry.

A `To Do` item that is dropped rather than done is moved to `Done` and marked as dropped, with the reason. Deleting it erases the fact that it was ever considered.

## Committing Spike Work
Repos differ on whether agents may commit. Follow the repo's own policy, stated in its `AGENTS.md` or its decision records. **If the repo says nothing, do not commit and do not offer to.**

Where agent commits are permitted, use the `commit-work` skill. Do not write commit logic, staging logic, or commit messages here; hand it the spike's slug and let it own the rest. It writes a `Spike: <slug>` trailer on each commit, which is what later allows a spike's history to be reconstructed:

```sh
git log --grep='Spike: <slug>$' --reverse
```

Commit at the **completion boundary** — when implementation is finished and verified as far as the terminal allows. This is independent of which bucket the item lands in: most work goes straight from `To Do` to `Done`, and only some stops at `Ready for Human QA`. The commit happens when the work is finished, and the bucket is chosen afterward. Do not wait for the user's QA confirmation to commit: it may arrive days later, or conversationally, or never, and finished work should not sit uncommitted in a tree another agent may be writing to.

The `.todo.md` edit that moves an item belongs in the same commit as the work it describes. One commit then shows both the change and its recorded intent.

When the user confirms QA, moving items to `Done` is its own doc-only commit, batched per **approval event**: one approval is one commit, however many items it covered. It records when the work was blessed, which no other artifact does.

Never push. Pushing is the user's.

## Human QA
Use `Ready for Human QA` for things the agent cannot fully verify from the terminal:

- interaction feel
- copy tone
- static preview sanity checks when the user is already testing in-browser
- shell behavior in the user's real terminal
- installer behavior on a real machine
- OS-specific setup that cannot be safely exercised from the current environment

Be specific. A good QA item names the surface, route, interaction, or visual state the user should inspect.

## Scratch Promotion
Use `docs/scratch/` for rough notes, copied references, draft outlines, and exploratory material that is not yet a spike or durable rule.

Scratch docs are not authoritative. Promote useful material into an active spike, durable doc, or runbook before relying on it.

Promotion means move, not copy. When promoting a scratch doc into `docs/active-spikes/`, move its useful content into the active conceptual and to-do docs, then delete or clearly retire the old scratch source. Do not leave an outdated duplicate in `docs/scratch/`.

If a scratch doc contains multiple themes, split it deliberately: move each useful piece into the right destination, then remove the routed source material. Preserve nuance and concrete user phrasing while moving it.

For loose unrouted notes, use `docs/scratch/misc.md` and the `triage-project-misc` skill.

## Durable Decisions
Decision records are part of the project's durable docs structure, not the spike process itself. During a spike, create or update a decision record only when a tradeoff has become a durable project rule that should outlive the spike.

Do not create decision records for every local implementation choice. Keep ordinary reasoning in the conceptual spike doc unless it needs to become long-lived project authority.

## Starting A Spike
1. Inspect `AGENTS.md`, `README.md`, `TODO.md`, `docs/active-spikes/`, `docs/scratch/`, `docs/archive/`, durable docs, and repo-local skills.
2. Decide whether the work belongs in an existing active spike, a new named spike, or a miscellaneous spike bucket.
3. Choose a short topic slug. For mixed work, use the repo's numbered misc convention.
4. Create or update `docs/active-spikes/<topic>.md` for conceptual context.
5. Create or update `docs/active-spikes/<topic>.todo.md` for implementation state.
6. Add or update the spike entry in `TODO.md` as an index pointer.
7. Capture known constraints, non-goals, validation expectations, and open questions before implementation if they matter.

## During A Spike
Keep conceptual understanding in the conceptual doc and operational state in the to-do doc. Update item statuses as work moves. Preserve enough history to explain decisions, but move durable rules out of the spike when they become repo policy.

Do not let scratch notes silently become authority. Promote them deliberately.

## Continuation Links
When work moves into a new phase instead of continuing in the same spike, link related predecessor and successor spikes so the work graph can be followed later.

Continuation is many-to-many. A spike can split into several successors, and a later spike can merge several predecessor threads.

Use one grep-friendly marker line per relationship, with stable literal repo paths rather than fragile relative links:

```md
Continues from: docs/archive/old-topic.md
Continues from: docs/archive/related-topic.md
Continues in: docs/active-spikes/new-topic.md
Continues in: docs/active-spikes/side-topic.md
```

Write `Continues from:` marker lines in successor conceptual docs. Write `Continues in:` marker lines in predecessor conceptual docs before archiving them. Add reciprocal links where practical. If linked docs later move from active to archive, keep the literal paths current during the archive pass.

Use continuation links when a spike is gated, handed off, superseded, split into a new phase, or intentionally closed while related work continues elsewhere. Do not use them for unrelated follow-up ideas.

## Archiving A Spike
When a spike is finished or superseded:

1. Review and update the conceptual and to-do docs to reflect progress.
2. Fold durable lessons into long-lived docs.
3. Add `Continues in:` / `Continues from:` links if related work continues in another spike.
4. Leave spike-local detail in the spike docs.
5. Move both spike docs from `docs/active-spikes/` to `docs/archive/`.
6. Update `TODO.md` so the active work index stays current.
7. Where agent commits are permitted, land the archival as a single commit via `commit-work`, with the spike summary as its message. Show the message to the user and commit on their approval.

Archived spike docs are historical context. They may be out of date. Do not treat archived docs as current project rules unless a durable doc still says the same thing.

### The Archival Commit
The archival is itself a commit: the doc moves and the `TODO.md` update are its diff. So its message is the spike's summary, and it is the one commit in a spike worth reviewing before it lands.

That message is a **synthesis, not a rollup**. Draw on the trailer log, the conceptual doc, the to-do doc's `Done` section, and what you still hold in working context. The most valuable content is what cannot be recovered from the diff: what was tried and abandoned, what turned out to be the wrong frame, which constraint was discovered halfway through, which argument was made well and then lost. **Dead ends leave no trace in the tree.** If they are not written down now, they are gone.

Write the summary message and do the archival doc pass as one act, from one synthesis.

## Durable Lessons Check
Before archiving, ask:

- Did commands, setup, public APIs, or workflows change? Update `README.md`.
- Did agent workflow change? Update `AGENTS.md` or the relevant repo-local skill.
- Did a durable tradeoff get settled? Add or update a decision record.
- Did shell load order, install behavior, or symlink behavior change? Update durable setup docs.
- Did the work add a repeatable manual process? Add or update a runbook or skill.
- Did it create future roadmap work? Update `TODO.md` or create a draft in `docs/scratch/`.
- Did it reveal private/public boundary concerns? Update safety docs or examples.
- Do durable docs still describe the repo's real shape?

The archive keeps the texture. Durable docs keep the rule.
