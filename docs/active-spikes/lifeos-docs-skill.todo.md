# LifeOS Docs Skill — To Do
## Background
`lifeos docs` shipped without a skill of its own. See the conceptual doc for the 2026-09-06 failure that motivated this.

## To Do
- (none)

## Ready for Human QA
- The two `install-script/functions/symlinks.sh` lines are unverified against a real installer run. They match the six sibling lines exactly, and the live symlinks were created by hand so the skill works now — but whether the installer reproduces them on a fresh machine has not been exercised. Confirm on the next `install` run.

## Done
- [x] Write `lifeos-tools/skills/lifeos-docs/SKILL.md`. → Written. Frontmatter `description` leads with the phrasings the need actually arrives in — "editing an existing native Google Doc", "updating a shared doc", "fixing or replacing a line", "adding a hyperlink to existing text" — because trigger language is the whole point of the spike. Body carries the safety model (dry-run default, exact-single-match, revision guard, `--docs-write`, no delete) plus two gotchas recovered from `docs/archive/google-doc-editing-via-lifeos.md`: typographic punctuation causing `found 0`, and the read collapsing mailto-linked names to empty. Added the replace-only consequence — inserting a line means replacing an anchor with itself plus the new content — and that an empty document cannot be edited at all, which is a real dead end hit on 2026-09-06.
- [x] Trim `lifeos-drive`'s "Editing an existing Doc" section to a pointer, keeping the routing. → Both the top-of-file note and the section now name the `lifeos-docs` skill rather than restating the command surface. Kept the section heading rather than deleting it: an agent scanning `lifeos-drive` for Doc editing should still land somewhere that redirects, which is the whole routing assumption the original design made and that this spike is preserving rather than discarding.
- [x] Add `lifeos-docs` to the `lifeos-cli` Service Skills list, and repoint its `--docs-write` note. → Done. The list now distinguishes creating a Doc (`lifeos-drive`) from changing one that exists (`lifeos-docs`), which is the distinction that was invisible before.
- [x] Register the skill in `install-script/functions/symlinks.sh` for both Codex and Claude. → Two lines added, one per host block, immediately after the `lifeos-drive` line. See the QA item above.
- [x] Run the skill validator. → `Skill is valid!` **The documented invocation does not work as written.** `quick_validate.py` imports `yaml`, which is present in neither the system `python3` nor `lifeos-tools/.venv`. It runs under `uv run --with pyyaml python …`. The `write-skills` skill gives the bare `python3` form, so anyone following it hits `ModuleNotFoundError` — worth a skills-feedback entry.
- [x] Create the two live symlinks in this working environment so the skill is usable now, not after the next install run. → Both created and verified resolving. The harness picked the skill up immediately.

## Notes
- The validator friction above is logged here rather than fixed, because correcting `write-skills` is a change to a global skill and outside this spike's scope.
