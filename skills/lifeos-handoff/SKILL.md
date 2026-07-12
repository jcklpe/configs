---
name: lifeos-handoff
description: "Use when the user asks to hand work off to LifeOS, report progress to LifeOS, log an accomplishment, give a LifeOS status update, or says 'LifeOS handoff' / 'log this to LifeOS'. Produces a sectioned progress report (Progress / Growth / Accomplishment) for the user to carry into their LifeOS vault. User-initiated only, never autonomous; never writes to the vault; never claims AI-executed work as something the user hand-did."
---

# LifeOS Handoff
## Local Precedence
If the current repo already has `skills/lifeos-handoff/SKILL.md`, read and follow the repo-local skill first. Treat this global skill as fallback seed material.

## What This Is
LifeOS is the user's personal life-tracking Markdown vault. Think of its agent as the user's **project manager**: someone who wants to know what the user is up to, how their projects are going, why things take the time they take, and what the user is learning and becoming along the way.

This skill produces that status report, from any repo, for the user to carry over. It is the **producer** half. The vault (the receiver) already knows how to file what it gets — so this skill produces good raw material and does **not** decide where it lands.

## When To Use
Only when the user asks — "hand this off to LifeOS", "log this", "give me a LifeOS progress update", "LifeOS handoff", and the like.

**Never on your own initiative.** Do not offer it, do not suggest logging to LifeOS, do not tack it onto an unrelated answer. Unprompted handoff nudges are noise. Silence unless asked.

## The Three Dimensions
A handoff is a report to a project manager, not just a resume line. Surface whichever of these the work actually touched — usually more than one:

- **Progress** — where a project stands, what moved, what is blocking it, and *why it is taking as long as it is*. The PM wants the pace-and-blocker story so it stops wondering why something is dragging. Agent-executed work belongs here: it is still the user's project and its real progress.
- **Growth** — the human development underneath the work: skills the user is building, things they are learning, new techniques, stacks, or tools they are experimenting with, workflows they are refining, new ideas and approaches. This is honest even when an agent did the typing, because the user is learning to define and direct the work — often the most valuable thing to track over time.
- **Accomplishment** — a concrete, claimable win, in the ledger shape below. This is the one with a strict honesty bar (next section), because it may become resume or portfolio material.

## Attribution: Credit The Real Contribution
The user directs and reviews work that an AI agent often executes. The report must reflect what the user can honestly stand behind.

- **In Progress and Growth**, describe agent-executed work as genuine project movement and genuine learning, and be clear *that* it was AI-executed under the user's direction. "Refactoring the CLI by directing an agent" is true and useful to the PM.
- **In Accomplishment, the bar is strict.** Credit the user's *actual* role — defining the problem, choosing the architecture, setting the constraints, the judgment calls, the errors they caught in review, the decisions they made, the effective direction of the tool. **Never phrase an AI-produced artifact as something the user hand-made.** "Refactored 2,550 lines into a dispatcher" is not defensible in an interview if an agent wrote it; "defined the architecture and safety constraints for, and directed, an AI-executed refactor that shipped with zero regression" is both true and stronger.

Infer the user's real role from the session — you can see what they approved, directed, decided, and caught. Ask only when it is genuinely unclear. Do not erase their part, and do not inflate it.

## Strategic Framing: Generic Only
A little framing toward transferable competencies helps — systems thinking, technical judgment, direction and leadership, process design, effective AI orchestration, and light gestures at the user's domains (e.g. civic tech, design/research ops) are fine.

But this skill lives in a **public** repo and cannot see the user's private career strategy. Do **not** invent or bake in specific positioning — named contacts, particular goals, "emphasize X to land Y". Harvest the facts and name generic competencies; the vault, which is private and holds the actual career context, does the specific positioning. When in doubt, report the fact and let the vault frame it.

## The Accomplishment Entry Shape
For the Accomplishment section, match the vault ledger's shape so it drops in unedited:

```md
- Date / period:
- Focus:
- Accomplishment:
- Evidence:
- Resume angle:
- Notes:
```

Fill it by the ledger's own rules: concrete facts (what changed, who benefited, what artifact or scope), real evidence (prefer things already in the repo — a commit range, a `Spike:` trailer query, an archived spike doc, a shipped file, a URL), numbers only when true (never invent metrics), and no vague praise.

## Where It Goes
Produce the sectioned report and hand it to the user. **Do not write to the vault, and do not presuppose its structure.** The vault evolves quickly — a folder or note that exists this week may be gone or renamed next week — so routing is the vault agent's job, not yours. Give clean, well-labeled sections; the vault agent files each where it currently belongs.

## Example
Handing off a finished refactor that an agent executed under the user's direction:

```md
### Progress
- Project: LifeOS Tools CLI (configs repo).
- Status: refactor complete and shipped — the 2,550-line lifeos.sh is now a 324-line dispatcher with feature modules in lib/, secrets and generated output moved into their own folders, behavior verified unchanged.
- How: AI-executed under my direction; I set the architecture, the constraints, and the judgment calls.
- Blockers/pace: none blocking; the secrets move surfaced a coupling to my private .env that I worked through.

### Growth
- Refined my spike + commit-work workflow on a large real refactor: small pathspec commits, golden-baseline verification after every step.
- Practicing directing an AI agent through a risky legacy refactor — caught a wrong assumption (a supposed gitignore leak that wasn't) and rejected a format-first folder split during review.
- Reinforced bash-3.2 portability and a clean module-extraction technique (function-name anchors).

### Accomplishment
- Date / period: 2026-07-11
- Focus: LifeOS Tools CLI maintainability
- Accomplishment: Defined the architecture and safety constraints for, and directed, an AI-executed refactor of a 2,550-line legacy bash tool into a modular 324-line dispatcher, shipped with zero behavioral regression verified against a golden baseline.
- Evidence: configs repo, `git log --grep='Spike: lifeos-code-cleanup'`; docs/archive/lifeos-code-cleanup.md
- Resume angle: technical judgment and effective AI-tool direction — architecting a legacy refactor and orchestrating its safe execution.
- Notes: kept bash-3.2 compatibility; caught a false gitignore-leak assumption and a format-first design error in review.
```
