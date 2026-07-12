---
name: lifeos-trello
description: "Use when reading or writing Trello through the lifeos CLI: listing boards/lists, syncing the Trello snapshot, creating/moving/renaming cards, setting descriptions, commenting, or linking task-chain cards with supersede. Covers the commands and Trello-specific safety (no hard-delete, description overwrite caveat, prefer comments)."
---

# LifeOS Trello
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-trello/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

The `sources/trello.md` snapshot is generated context, not a write-back database. Read it to understand Trello state, but make changes only through `lifeos trello ...` commands, then refresh the snapshot. See `lifeos-cli` for the shared rules.

## Reads
```sh
lifeos trello list-boards
lifeos trello list-lists
lifeos trello sync
```

`lifeos trello sync` writes the current snapshot to `$LIFEOS_VAULT_PATH/sources/trello.md` (or, with `--qa`, to `~/configs/lifeos-tools/qa/trello-qa.md` for local inspection).

The snapshot groups cards by board heading. If multiple boards are configured, `list-lists` without an argument uses the first configured board; use `lifeos trello list-lists BOARD_ID` for a specific one, and pass `--board BOARD_ID` on writes to a non-default board. Run `list-lists` before using list names if the board taxonomy may have changed. Prefer card URLs or IDs for card operations.

## Writes
```sh
lifeos trello add-card --list "On Deck" --name "Task name" --desc "Optional description" [--board BOARD_ID]
lifeos trello move-card --card CARD_ID_OR_URL --list Done [--board BOARD_ID]
lifeos trello rename-card --card CARD_ID_OR_URL --name "New task name"
lifeos trello set-desc --card CARD_ID_OR_URL --file /tmp/card-desc.md
lifeos trello comment --card CARD_ID_OR_URL --text "Comment text"
```

Run `lifeos trello sync` after any write to refresh the snapshot.

## Task Chains (supersede)
When a card hits a gate — a wait on an external party, a future date, a handoff, or a substantial prerequisite — do not keep mutating it. Create a successor and link them. `supersede` writes the bidirectional link atomically (a `🔗 Continues in:` comment on the predecessor and a `🔗 Continues from:` comment on the successor), so it can't be left half-applied:

```sh
# link two existing cards
lifeos trello supersede --from PRED_CARD_ID_OR_URL --to SUCC_CARD_ID_OR_URL [--board BOARD_ID]
# create the successor and link it in one step
lifeos trello supersede --create --from PRED_CARD_ID_OR_URL --list "On Deck" --name "Next leg" [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
```

Re-running is idempotent (only the missing link is added). If it prints `PARTIAL:`, the back-link landed but the forward-link did not — re-run to complete it. `supersede` does **not** move the predecessor; use `move-card` separately if you want it in a Done list. Deciding *when* to split at a gate is your judgment, not the tool's.

Print a chain from any member card:

```sh
lifeos trello chain --card ANY_CARD_ID_OR_URL [--json]
```

## Safety
- Do not hard-delete Trello cards.
- `set-desc` overwrites the full description. Prefer `comment` for additive notes; task-chain links are stored as comments for this reason.
- Trello writes have no dry-run or before/after output yet, including `supersede` — confirm the target before running.
