# LifeOS Handoff To-Do
Status: **active.** Design settled in the conceptual doc; this tracks execution.

Conceptual doc: `docs/active-spikes/lifeos-handoff.md`.

## Background
LifeOS already receives accomplishments (vault `AGENTS.md` + `career/accomplishments.md`). This spike builds the missing producer half: a global, user-initiated `lifeos-handoff` skill that generates a ledger-ready handoff blurb from any repo. Design worked out 2026-07-09..11.

## Project Organization
- `skills/lifeos-handoff/SKILL.md` — the new global skill. Agent-neutral.
- `install-script/functions/symlinks.sh` — add the symlink into the Codex and Claude global skill dirs, matching the existing per-skill calls.
- `agents/AGENTS.global.md` — one-line LifeOS pointer (and its verbatim mirror concern: this rule is global, so it does NOT also go in configs/AGENTS.md — only the Markdown/prose rules are mirrored there).

## General Principles
- User-initiated only. Never autonomous, never a nudge.
- Produce text; never write to the vault.
- Coarser than commits: milestones and shipped work, not a changelog.
- Output matches the vault ledger's entry shape so it drops in unedited.
- Prefer existing evidence (commit ranges, archived spike docs, artifacts) over invented prose; no fabricated metrics.

## Current State Overview
Nothing built yet. The vault side is mature and untouched: `career/accomplishments.md` has a defined entry shape (Date/Focus/Accomplishment/Evidence/Resume angle/Notes) and a "Current Harvest Queue", and the vault `AGENTS.md` already instructs in-vault agents to harvest into it.

## To Do
- [ ] Verify: the skill surfaces in a fresh session (its description appears), and a dry run produces a blurb in the correct entry shape from a real example (e.g. hand off the lifeos-code-cleanup spike and confirm the output would drop cleanly into the ledger).
- [ ] Verify: the skill surfaces in a fresh session (its description appears), and a dry run produces a blurb in the correct entry shape from a real example (e.g. hand off the lifeos-code-cleanup spike and confirm the output would drop cleanly into the ledger).

## Ready for Human QA
- Likely: confirm the handoff blurb's tone and shape feel right when pasted into the real `career/accomplishments.md`, and that the granularity matches what the user wants LifeOS to track (not too fine).

## Done
- [x] **Write `skills/lifeos-handoff/SKILL.md`.** Done. Covers what LifeOS is, when-to-invoke (user-request only, explicit "never unprompted"), the two flavors, the exact ledger entry shape, the fill rules (real evidence, no invented metrics, no vague praise, coarser than commits), the paste destination, and a worked example (handing off lifeos-code-cleanup). Description leads with triggers and the "user-initiated, never writes the vault" boundary.
- [x] **Add the `lifeos-handoff` symlink to the Codex and Claude blocks of `install-script/functions/symlinks.sh`, and create the two symlinks directly so it is live without a full installer run.** Done; both `~/.claude/skills/lifeos-handoff` and `~/.codex/skills/lifeos-handoff` are live, and the skill surfaces in this session's skill list.
- [x] **Add the one-line LifeOS pointer to `agents/AGENTS.global.md` (global scope — not mirrored into configs/AGENTS.md, since that mirror is only for the Markdown/prose rules).** Done as a two-line `## LifeOS` section: what LifeOS is + use `lifeos-handoff` when asked, never unprompted. Position-independent (states a preference, names no repo). Deliberately not added to `configs/AGENTS.md` — only the prose-style rules are mirrored there.

## Public Safety And Secrets
The skill is agent-neutral and global; it hardcodes no repo-private or vault-private paths in a way that would break elsewhere. Naming the vault's ledger file as the paste destination is a stable personal fact, acceptable in a global skill. No secrets involved.

## Validation
No test suite. Validate by: reading the skill as an agent in a *different* repo (does it make sense out of context?), and a dry run that produces a real handoff blurb and checks it against the ledger's entry shape.
