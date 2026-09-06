# LifeOS Docs Skill
Give `lifeos docs` its own skill, so the Doc-editing capability is discoverable by the same route as every other service.

## Why
`lifeos docs read` / `replace-once` shipped in the LifeOS Docs Editing spike and works correctly. Its guidance was written into `lifeos-drive` rather than into a skill of its own, on the reasonable theory that someone looking for Doc editing would start at `drive`.

That theory failed in practice on 2026-09-06. An agent asked to edit a shared Google Doc concluded the capability did not exist, reached for the Open Austin repo's `tools/google-docs/` instead, got a 403 because that tool authenticates as the `open-austin` account, and proposed building a command that already existed. It had the correct `lifeos-drive` skill available and did not open it, because nothing in the skill *names* pointed at Doc editing.

**The failure is a naming/trigger failure, not a documentation-quality failure.** The `lifeos-drive` skill's text was accurate and explicit. An agent scanning a list of skill names sees `lifeos-trello`, `lifeos-calendar`, `lifeos-gmail`, `lifeos-drive`, `lifeos-m365`, `lifeos-open-austin` — six services, no `docs` — and reasonably infers there is no Doc surface. A skill's `description` is trigger language; a capability with no skill has no trigger.

## Goals
- One skill per command group, matching the shape the other six already establish.
- Trigger language covering how the need is actually phrased: edit a Google Doc, update a shared doc, fix a line in a Doc, add a link to a Doc.
- Preserve the safety model in the skill text: dry-run default, revision guard, exactly-one-match, `--docs-write` scope, `--execute` required.

## Non-Goals
- No change to `lifeos docs` behaviour. The command is correct; only its discoverability is not.
- Not removing the pointer from `lifeos-drive`. Someone reasoning "Drive holds Docs" should still be routed. The pointer stays; the detail moves.
- Not resolving the Open Austin duplication. Decision `0005-docs-editing-in-lifeos-tools.md` settled that deliberately.

## Constraints
- Skills are symlinked into `~/.codex/skills/` and `~/.claude/skills/` by `install-script/functions/symlinks.sh`. A new skill that is not registered there exists in the repo and nowhere an agent will look — which is this spike's own failure mode, repeated.
- Seed text is position-independent: write conditions ("if the current repo already has…"), never deictic facts.

## Relationship To Other Work
Continues from: docs/archive/lifeos-docs-editing.md
