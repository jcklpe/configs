# How To Run A Spike

This dotfiles repo uses focused work spikes when a body of work needs more shared context than a normal ticket or one-off task can carry.

A spike is not just a checklist. It is a temporary collaboration space for the user and agents to build taste, vocabulary, decisions, and implementation history around a specific theme of work.

Spikes are useful here because `configs/` is both personal and portable. Changes often need to answer more than "does it work?": they need to fit the shell load order, stay safe for a public repo, avoid secrets, remain idempotent across machines, and avoid slowing down startup.

## Authority Ladder

Use docs according to their authority:

- `AGENTS.md`, `README.md`, and active decision records are durable project rules.
- `docs/how-to-spike.md` explains this work process.
- Active spike docs explain current thinking for a theme of work.
- Active spike to-do docs track implementation state.
- `TODO.md` is the coordination map across spikes and backlog items.
- `docs/scratch/` is non-authoritative working material.
- `docs/archive/` is historical context, not current rules unless a durable doc still agrees with it.

## The Two Documents

Most active spikes use two docs:

- A **conceptual doc**, such as `docs/lifeos-tools.md`.
- A **to-do doc**, such as `docs/lifeos-tools.todo.md`.

The conceptual doc explains the work’s purpose, philosophy, boundaries, and settled model. It should help a new agent understand what kind of solution would be in character for the project.

The to-do doc tracks concrete implementation work. It should be operational: files, actions, QA notes, unresolved questions, and what has already happened.

For now, this guide lives at `docs/how-to-spike.md`. If this repo grows more process docs, move it to something like `docs/process/spikes.md` and leave a short pointer here.

## Conceptual Docs

Use the conceptual doc for:

- goals and non-goals
- project vocabulary
- shell/setup/engineering philosophy
- major decisions and why they were made
- relationship to other spikes
- constraints that should shape future work

Avoid turning the conceptual doc into a running changelog. When implementation details become durable project rules, fold them into longer-lived docs such as `README.md`, `AGENTS.md`, a decision record, a runbook, or another active reference doc.

## To-Do Docs

Use the to-do doc for:

- concrete atomic work items
- current state notes
- implementation progress
- commands and verification steps
- human QA requests
- known edge cases
- short historical notes that will help future agents reconstruct what happened

The to-do doc usually follows this rough structure:

- Background
- Project Organization
- General Principles
- Current State Overview
- To Do
- Ready for Human QA
- Done

Exact headings can flex when needed, but future agents should be able to find current work, QA work, and completed work quickly.

For this repo, consider adding sections for:

- public safety and secrets
- shell startup impact
- install and symlink impact
- OS matrix: macOS, Fedora, NixOS, WSL, generic Linux
- validation commands
- rollback or recovery notes
- whether the work belongs in this public repo or somewhere private

## Moving Work

Work starts in `To Do`.

When an agent finishes implementation but the user needs to visually or manually verify it, move the item to `Ready for Human QA`.

When the user confirms QA, move it to `Done`.

When implementation does not need human QA, move it directly to `Done` after verification.

`Done` is allowed to preserve useful history. It does not need to be a perfectly compressed final summary. These docs are archived at the end of the spike, and that archive can help future agents understand why the code ended up this way, even if the notes along the way are messy or not totally current. Prefer a useful decision and implementation trail over a neat but context-poor summary. Do not sand off the rough corners of historical artifacts.

## Human QA

Use `Ready for Human QA` for things the agent cannot fully verify from the terminal:

- interaction feel
- copy tone
- static preview sanity checks when the user is already testing in-browser
- shell behavior in the user's real terminal
- installer behavior on a real machine
- OS-specific setup that cannot be safely exercised from the current environment

Be specific. A good QA item names the surface, route, interaction, or visual state the user should inspect.

## Scratch Docs

Use `docs/scratch/` for rough notes, copied references, draft outlines, and exploratory material that is not yet a spike or durable rule.

Scratch docs are not authoritative. Promote useful material into a spike, decision record, runbook, `README.md`, or `AGENTS.md` before relying on it.

## Decision Records

Use `docs/decisions/` for decisions that should outlive a spike. Keep them short:

- context
- decision
- consequences
- links to related spikes or docs

Prefer numbered names such as `0001-docs-workflow.md` once there is more than one decision.

## Archiving A Spike

When a spike is finished:

1. Review the conceptual and to-do docs.
2. Fold durable lessons into long-lived docs.
3. Leave spike-local detail in the spike docs.
4. Move both spike docs to `docs/archive/`.
5. Update `TODO.md` so the active work map stays current.

Archived spike docs are historical context. They may be out of date. Do not treat archived docs as current project rules unless a durable doc still says the same thing.

## Durable Lessons

Before archiving, ask:

- Did we add or rename commands? Update `README.md`.
- Did we change agent workflow? Update `AGENTS.md` or this doc.
- Did we settle a durable tradeoff? Add or update a decision record.
- Did we change shell load order, install behavior, or symlink behavior? Update `AGENTS.md`.
- Did we add a repeatable manual process? Add or update a dedicated runbook.
- Did we create future roadmap work? Update `TODO.md` or create a draft in `docs/scratch/`.
- Did we learn something that should affect future machine setup? Update the relevant installer, README, runbook, or decision record.
- Ask more questions than just these. Always check whether the durable docs still describe the repo's real shape.

The archive keeps the texture. Durable docs keep the rule.
