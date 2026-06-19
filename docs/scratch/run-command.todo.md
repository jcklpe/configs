# Run Command To-Do

Status: scratch to-do. Not active work.

Conceptual doc: `docs/scratch/run-command.md`.

## Background

This topic was parked after adding `run --list`.

The motivating examples were:

- `run install` in an npm project unexpectedly mapping to `npm exec install`
- `run run dev` unexpectedly mapping to `npm exec run dev`

The user goal is broader than those examples: make `run` feel like the contextual project command without rushing into a brittle redesign.

## Project Organization

Relevant files:

- `plugins/run/run.sh`
- `plugins/run/completion.zsh`
- `plugins/run/completion.bash`
- `AGENTS.md`

Validation surface:

- fresh `bash` shell
- fresh `zsh` shell
- JS project
- Python project
- mixed-root project if possible

## General Principles

- Prefer a coherent dispatch model over command-specific patches.
- Preserve current shorthand behavior unless there is a strong reason to break it.
- Keep the implementation understandable enough that future agents can safely extend it.
- Optimize for low surprise, not maximum cleverness.

## Current State Overview

- `run --list` and `runjs --list` were added on June 18, 2026.
- Bare `run` still lists as before.
- No broader semantic redesign has been implemented yet.
- The current fallback logic still prefers Python `run` wrappers, then JS `<pm> exec`.

## To Do

- Decide the intended precedence between:
  local scripts/recipes/targets, native tool subcommands, env-executed binaries.
- Define what "primary project tool" means when both JS and Python tooling exist at the same root.
- Investigate whether native subcommands can be discovered cheaply enough for:
  npm, pnpm, yarn, bun, poetry, uv, pixi, pipenv.
- Sketch at least three concrete dispatch examples per ecosystem before coding:
  install, dev-like task, arbitrary binary.
- Decide whether `runjs` stays as-is or changes role after any `run` redesign.
- Decide whether completion should eventually include native subcommands, and if so, how aggressively.

## Ready For Human QA

- None. This topic is parked.

## Done

- Added explicit `run --list` support.
- Added explicit `runjs --list` support.
- Updated shell completion so `--list` appears as a first-arg suggestion.
- Updated `AGENTS.md` to mention `--list`.
- Parked the broader `run` redesign behind this scratch spike instead of continuing to change behavior ad hoc.
