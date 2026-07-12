# LifeOS CLI Skill To-Do
Status: **active.** Conceptual doc: `docs/active-spikes/lifeos-cli-skill.md`.

## Background
Formalize `lifeos-tools/AGENT.md` (the `lifeos` CLI agent guide) into a co-located tool skill at `lifeos-tools/skills/lifeos-cli/SKILL.md`, symlinked global, and update every reference to point at it. The configs half of the runbook-conversion effort; the vault half is tracked in the vault at `docs/spike.runbook-conversion.*`.

## General Principles
- Co-located tool skill; no vault-private detail in it (public repo).
- Delete `AGENT.md`; update all references to the skill (including decision `0002`).
- Vault-side references are the vault spike's job; note them there.
- One commit per coherent change; `Spike: lifeos-cli-skill` trailer.

## To Do
- Nothing open. This half is done pending the vault-side reference repoint (tracked in the vault spike).

## Ready for Human QA
- None expected; this is a docs move. Possibly: confirm the skill's description/triggers read well.

## Done
- [x] **Create `lifeos-tools/skills/lifeos-cli/SKILL.md`.** Frontmatter with a triggers-first description; the `AGENT.md` guide as the body. Fixed three stale QA paths carried over from before the lifeos-code-cleanup move (`trello-qa.md`/`calendar-qa.md`/`gmail-qa/` → `qa/…`) — a durable-lessons miss from that spike, caught here.
- [x] **Delete `lifeos-tools/AGENT.md`.** Content is now the skill; git detects the move.
- [x] **Update configs references to `AGENT.md` → the skill.** `lifeos-tools/README.md` (rewrote the "usage notes" note; removed the now-obsolete vault-symlink recipe), decision `0002` (the Links entry plus two prose mentions), and the live `lifeos-tools-v2.md` mention. Left the completed historical `lifeos-tools-v2.todo.md` entry untouched — rewriting a done history item is wrong.
- [x] **Add the `lifeos-cli` symlink to `symlinks.sh` and create it live.** Both `~/.claude/skills/lifeos-cli` and `~/.codex/skills/lifeos-cli` are live; the skill surfaces in-session.
- [x] **Add the vault-side reference updates to the vault spike's to-do.** Done — the vault `AGENTS.md`/`operating-procedures.md`/`decisions.md`/`runbooks/README.md` repoint is now a task in `LifeOS/docs/spike.runbook-conversion.todo.md`.
- [x] **Verify.** Skill surfaces in-session; no dangling *live* configs reference to `AGENT.md` (remaining mentions are spike docs describing the work + the historical todo entry); `symlinks.sh` syntax clean; behavior unaffected (docs-only move).

- [x] **Open the spike and cross-link it to the vault spike.** Created the conceptual + to-do pair in `docs/active-spikes/`, noting the conjoined vault spike.
