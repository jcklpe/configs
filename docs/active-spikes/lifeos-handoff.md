# LifeOS Handoff
Status: **active spike.** Opened 2026-07-11. Build a user-initiated global `lifeos-handoff` skill that produces a progress/accomplishment handoff blurb, from any repo, formatted for the LifeOS vault's accomplishments ledger.

Companion to-do: `docs/active-spikes/lifeos-handoff.todo.md`.

Second of three sibling LifeOS spikes from the design conversation of 2026-07-09..11. Siblings: `docs/archive/lifeos-code-cleanup.md` (shipped) and Vault Runbook Conversion (not yet opened).

## Purpose
LifeOS already knows how to *receive* accomplishments. Its `AGENTS.md` tells any agent working *inside the vault* to accrete career-relevant outcomes into `career/accomplishments.md`, a durable raw-material ledger. What is missing is the *producer* half: when the user does real work in a **different** repo — configs, a website project, anywhere — there is no way to hand LifeOS a summary of that progress without the user reconstructing it from memory later.

This skill fills that gap. Invoked from any repo, it produces a handoff blurb — progress on a project, or a concrete accomplishment — shaped to drop straight into the vault's ledger. The user carries it over; the skill does not touch the vault.

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

## Progress vs Accomplishment
The user wants two flavors, and the skill should handle both:

- **Accomplishment** — a completed, resume-relevant outcome. Full entry shape.
- **Progress update** — "here's where project X stands and what moved," which may not be resume-worthy yet. A lighter note, still dated and evidenced, suitable for the harvest queue or a project note.

The skill asks or infers which is wanted, and does not inflate a progress update into a false accomplishment.

## Where The Material Comes From
Invoked in a repo, the skill draws on what is actually available: the session's work, the git log (especially `Spike:` trailers and archival summaries, which are already synthesized), spike docs, and what the user says the handoff is about. It favors evidence that already exists — a commit range, an archived spike doc, a shipped artifact — over prose it makes up.

## Constraints
- `AGENTS.global.md` is read from inside every repo, so its LifeOS pointer must state a preference, never a fact about a location, and must stay to roughly one line (the file's value is being short). The skill body carries the substance; the pointer just names it.
- The skill is agent-neutral and global — no configs-specific or vault-private paths hardcoded in a way that breaks in another repo. It may name the vault's ledger file as the destination, since that is a stable personal fact, not a repo fact.

## Relationship To Other Spikes
Continues from: docs/archive/lifeos-code-cleanup.md
Sibling: Vault Runbook Conversion (not yet opened). Independent of both — it can ship without them.

## Open Questions
- Should the pointer live in `AGENTS.global.md` at all, or is the skill's own `description` enough? A global skill is already surfaced by its description. The pointer buys *ambient* awareness (an agent knows "LifeOS" is a thing the user references) at a small always-loaded cost. Leaning: include a single line, because "hand this to LifeOS" is a phrase the user will use across repos and agents should know what it means.
- Does the skill ever help the user actually *append* to the ledger when it happens to be run inside the vault or a repo with vault access, or is it always produce-only? Leaning produce-only for simplicity and safety; revisit if the friction of manual paste proves annoying.
