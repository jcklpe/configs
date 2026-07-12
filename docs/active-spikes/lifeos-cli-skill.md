# LifeOS CLI Skill
Status: **active spike.** Opened 2026-07-12. The configs half of the LifeOS runbook conversion: formalize the `lifeos` CLI agent guide (`lifeos-tools/AGENT.md`) into a proper, co-located tool skill.

Companion to-do: `docs/active-spikes/lifeos-cli-skill.todo.md`.

Continues from: docs/archive/lifeos-code-cleanup.md

## Conjoined With A Vault Spike
This is one of two conjoined spikes doing one body of work across two repos. The **vault spike** — `LifeOS/docs/spike.runbook-conversion.*` (Drive, no git) — converts the vault's seven operating-policy runbooks into vault skills, vendors a git-stripped `run-project-spike`, retires `how-to-spike.md`, and migrates the vault to `active-spikes/`. **This configs spike** handles the one tool-side piece: the CLI mechanics, which live in configs.

The sort (done in the vault spike) found that only `lifeos-tools.md` was genuinely tool-side, and it is already `configs/lifeos-tools/AGENT.md`. So the configs work is exactly one thing: make `AGENT.md` a proper skill.

## Goals
- Move the CLI guide content into `configs/lifeos-tools/skills/lifeos-cli/SKILL.md` — a proper skill (frontmatter, description), co-located with the tool.
- Symlink it into `~/.claude/skills/` and `~/.codex/skills/` via `symlinks.sh`, so local agents get it globally (not only the vault, as the old `AGENT.md` symlink did).
- Update every reference to `AGENT.md` — configs `README.md`, decision `0002`, and the vault docs — to point at the skill. No stale pointer; `AGENT.md` is deleted.

## Decisions
- **Co-locate the skill with the tool** (`lifeos-tools/skills/`), not in the top-level `skills/` library. It is tool-specific, and `AGENTS.md` already prescribes this for tool-specific skills.
- **Delete `AGENT.md` and update all references**, rather than leaving a pointer. Cleaner end state; the decision record gets edited too.
- **Vault-side references to `AGENT.md`** (vault `AGENTS.md`, `operating-procedures.md`, `decisions.md`, `runbooks/README.md`) are updated in the **vault** spike pass, since they are vault files (no git) and the `runbooks/lifeos-tools.md` symlink is being deleted there anyway. Tracked as a task in the vault spike's to-do.

## Split Into Service Skills (2026-07-12)
Reverses the original "one skill" plan, at the user's call. The single `lifeos-cli` skill is split into a thin core plus one skill per service:

- `lifeos-cli` — thin core: what the tool is, the Core Rule, `doctor`, Google account setup (shared by Gmail/Drive), the snapshot/`--qa` pattern, cross-cutting safety, and pointers.
- `lifeos-trello`, `lifeos-calendar` (incl. attendee resolution + availability), `lifeos-gmail`, `lifeos-drive`, `lifeos-open-austin` — one per service.

**Why split the skill when the code stays a cohesive app.** The `lifeos.sh` refactor deliberately did *not* organize the code skills-first, because code has shared infrastructure (the Google auth layer serves calendar/gmail/drive/people). A skill is agent-facing *guidance*, which has almost no shared infrastructure — an agent doing Trello work does not want the calendar write-safety model in its context. So the two layers pull opposite ways and both are right: cohesive app for the code, per-service split for the guidance. Each service skill gets a tight, service-specific `description` so it triggers precisely.

## Non-Goals
- Not changing what the guide says beyond what skill form and the split require.

## Constraints
- The skill is co-located in `lifeos-tools/` (public repo) and contains **no vault-private detail** — it is CLI mechanics only. Anything needing vault-private policy belongs in a vault skill, not here.
- bash/tool behavior is unchanged; this is a docs move.

## Open Questions
- Skill name: `lifeos-cli` (chosen — clear, distinct from the `lifeos-tools/` folder name). Revisit only if it reads oddly.
