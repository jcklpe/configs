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
- [ ] Create `lifeos-tools/skills/lifeos-cli/SKILL.md`: frontmatter (name `lifeos-cli`, a triggers-first description), then the `AGENT.md` guide content as the body.
- [ ] Delete `lifeos-tools/AGENT.md`.
- [ ] Update configs references to `AGENT.md` → the skill: `lifeos-tools/README.md` (the "Agent-facing usage notes" note and the symlink recipe), `docs/decisions/0002-lifeos-calendar-writes.md` (the link + prose), and `docs/active-spikes/lifeos-tools-v2.*` if the references there are still live.
- [ ] Add the `lifeos-cli` symlink to the Codex and Claude blocks of `install-script/functions/symlinks.sh`, and create the two symlinks directly so it is live now.
- [ ] Add the vault-side reference updates to the **vault** spike's to-do (vault `AGENTS.md`, `operating-procedures.md`, `decisions.md`, `runbooks/README.md`), since those are vault files.
- [ ] Verify: the skill surfaces in a session; `bash -n`/CLI behavior unaffected (docs-only); no dangling configs reference to `AGENT.md`.

## Ready for Human QA
- None expected; this is a docs move. Possibly: confirm the skill's description/triggers read well.

## Done
- [x] **Open the spike and cross-link it to the vault spike.** Created the conceptual + to-do pair in `docs/active-spikes/`, noting the conjoined vault spike.
