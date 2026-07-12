# LifeOS Handoff
Status: **active spike.** Opened 2026-07-11. Build a user-initiated global `lifeos-handoff` skill that produces a progress/accomplishment handoff blurb, from any repo, formatted for the LifeOS vault's accomplishments ledger.

Companion to-do: `docs/active-spikes/lifeos-handoff.todo.md`.

Second of three sibling LifeOS spikes from the design conversation of 2026-07-09..11. Siblings: `docs/archive/lifeos-code-cleanup.md` (shipped) and Vault Runbook Conversion (not yet opened).

## Purpose
Treat the LifeOS vault agent as the user's **project manager**: it wants to know what the user is up to, how their projects are going, why things take the time they take, and what the user is learning and becoming. Today there is no way to report that from a *different* repo — configs, a website project, anywhere the user actually works — without reconstructing it from memory later.

This skill is the **producer** of that report. Invoked from any repo, it emits a sectioned status report the user carries into the vault. It does not touch the vault, and it does not decide where the material lands — the vault (receiver) handles filing.

Accomplishment harvesting for resume/career material is *one facet* of the report, not the whole of it. The vault's `AGENTS.md` + `career/accomplishments.md` already handle the receiver side of that facet.

## The Two Halves
- **Receiver (already exists, in the vault):** the vault's `AGENTS.md` + `career/accomplishments.md`. An agent working in the vault harvests accomplishments into the ledger.
- **Producer (this spike, in configs):** the global `lifeos-handoff` skill. An agent working anywhere produces a ledger-ready blurb on request.

The two never run in the same place, which is exactly why the producer is a separate, global skill rather than a vault convention.

## Goals
- A `skills/lifeos-handoff/SKILL.md` that, on request, summarizes the session's or project's progress as a handoff blurb in the vault's entry shape.
- Symlink it into `~/.claude/skills/` and `~/.codex/skills/` via `symlinks.sh`, like the other global skills.
- A one-line LifeOS pointer in `agents/AGENTS.global.md` so every agent has ambient awareness that LifeOS exists and that this skill feeds it.

## Non-Goals
- **Not autonomous.** The skill never proactively offers or generates handoffs. It runs only when the user asks. Unprompted "should I log this to LifeOS?" nudges are exactly the noise the user does not want.
- **Not a vault writer.** It produces text for the user to paste; it does not write to the vault (the vault is not reachable from most repos, and the user curates what lands).
- **Not repo-history granularity.** A handoff is coarser than commits — milestones, shipped work, notable outcomes across a body of work, not a changelog. The user explicitly does not want LifeOS mirroring per-commit detail.
- **No new receiver logic.** The vault's ledger and its `AGENTS.md` instruction are the receiver and stay as they are.

## The Vault's Entry Shape
The producer's output must match what `career/accomplishments.md` expects, so it drops in without reshaping. The ledger's stated "good entry shape" is:

```md
- Date / period:
- Focus:
- Accomplishment:
- Evidence:
- Resume angle:
- Notes:
```

The ledger also has a "Current Harvest Queue" for not-yet-resume-ready material. The skill's output should be ready for either, and should follow the ledger's own guidance: concrete facts (what changed, who benefited, what artifact/scope), evidence links, numbers only when real, no invented metrics, no vague praise.

## The Three Dimensions
The report carries up to three things; most handoffs touch more than one:

- **Progress** — where a project stands, what moved, what is blocking it, and *why it is taking as long as it is*. The PM wants the pace-and-blocker story. Agent-executed work belongs here — it is still the user's project.
- **Growth** — the human development under the work: skills built, things learned, new techniques/stacks/tools tried, workflows refined, new ideas. Honest even for agent-executed work, because the user is learning to define and direct it. Often the most valuable thing to track over time.
- **Accomplishment** — a concrete, claimable win in the ledger's entry shape; the one facet with a strict honesty bar.

## Attribution: The Central Nuance
This is the decision that shaped the skill. The user directs and reviews work an AI agent often executes, so the report must reflect what the user can honestly stand behind.

In **Progress** and **Growth**, agent-executed work is reported as real project movement and real learning, made clear that it was AI-executed under the user's direction. In **Accomplishment**, the bar is strict: credit the user's actual contribution — defining the problem, the architecture, the constraints, the judgment calls, the errors caught in review, the decisions, the effective direction of the tool — and never phrase an AI-produced artifact as something the user hand-made. "Directed and architected an AI-executed refactor that shipped with zero regression" is true and defensible; "refactored 2,550 lines" is not, if an agent wrote it.

The reframe resolves the tension rather than suppressing it: framing the work as the user's *direction and judgment* is simultaneously the honest attribution and the more strategic, more 2026-relevant competency. The agent producing the handoff infers the user's real role from the session (what they approved, directed, decided, caught) and asks only when genuinely unclear.

## Strategic Framing Stays Generic
The producer lives in a public repo and cannot see the user's private career strategy. It may name generic transferable competencies (systems thinking, technical judgment, direction, process design, AI orchestration) and gesture lightly at the user's domains, but must not bake in specific positioning — named contacts, particular goals, "emphasize X to land Y". Specific positioning is the vault's job, because the vault is private and holds the career context. Harvest facts; let the vault frame.

## Destinations Are The Vault's Job
The producer emits cleanly-labeled sections and hands them over. It does **not** presuppose the vault's structure or route the material, because the vault evolves quickly — a note or folder that exists this week may be gone or renamed next week. Routing is the vault agent's job. The one stable format the producer commits to is the accomplishment entry shape below, since that facet has a known ledger shape.

## Where The Material Comes From
Invoked in a repo, the skill draws on what is actually available: the session's work, the git log (especially `Spike:` trailers and archival summaries, which are already synthesized), spike docs, and what the user says the handoff is about. It favors evidence that already exists — a commit range, an archived spike doc, a shipped artifact — over prose it makes up.

## Constraints
- `AGENTS.global.md` is read from inside every repo, so its LifeOS pointer must state a preference, never a fact about a location, and must stay to roughly one line (the file's value is being short). The skill body carries the substance; the pointer just names it.
- The skill is agent-neutral and global — no configs-specific or vault-private paths hardcoded in a way that breaks in another repo. It may name the vault's ledger file as the destination, since that is a stable personal fact, not a repo fact.

## Relationship To Other Spikes
Continues from: docs/archive/lifeos-code-cleanup.md
Sibling: Vault Runbook Conversion (not yet opened). Independent of both — it can ship without them.

## Settled During Human QA (2026-07-11)
The first draft was accomplishment-only and over-claimed AI-executed work as the user's. Reviewing a dry-run blurb with the user settled the model above:

- It is a **PM status report**, not an accomplishment harvester; three dimensions, not two flavors.
- **Attribution** is strict on the accomplishment facet and permissive-but-honest on progress/growth.
- **Keep the `Resume angle` field** — it frames the material toward concrete wins, which is part of the point.
- **Infer the user's role from the session; ask only when unclear** — the user is present in the working context, so inference should usually suffice.
- **Light gestures at domains are fine; specific private strategy is not** (no named contacts or goals).
- **Produce sectioned material; the vault agent routes it** — the producer must not presuppose the vault's dynamically-evolving structure.

## Open Questions
- Does the skill ever help the user actually *append* to the vault when run somewhere with vault access, or is it always produce-only? Leaning produce-only for simplicity and safety; revisit if manual paste proves annoying.
