# Misc Inbox
Live inbox for loose, unrouted observations: small bugs noticed in passing, taste reactions, half-formed feature ideas, "this should maybe be better someday" notes. Real enough to keep, too raw to file yet.

Not a roadmap, not an archive. When an item earns a home, route it with the `triage-project-misc` skill into a thematic scratch doc, a numbered `misc-N.md` bucket, an active spike, or a durable doc — then delete it from here.

## Unrouted Items
- **Skill-improvement feedback loop** (2026-07-11). A lightweight way to accrete suggested skill improvements as agents use skills, short of the Superpowers TDD approach the user rejected. Recommended shape: a one-line *trigger* in `agents/AGENTS.global.md` ("when you hit real friction using a skill and see a concrete fix, append a dated note to the skill-feedback log — log it, don't act on it"), and the accreting *log* in a scratch doc like `docs/scratch/skill-feedback.md` — not in the global file, which would bloat every repo's context. Triage periodically with `triage-project-misc` to promote good suggestions into the skills and drop the rest. Guardrails: concrete friction only, not nitpicks; backlog, not auto-apply. For global skills a local agent appends to `~/configs/...` directly; for vendored copies, feedback accrues in that repo and syncs back via the `setup-local-skills` update flow. Candidate for its own small spike.

## Latest Routing Session
- None yet.
