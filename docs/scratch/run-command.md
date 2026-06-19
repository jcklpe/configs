# Run Command

Status: scratch spike. Parked future work for the first-party `run` plugin.

Companion to-do: `docs/scratch/run-command.todo.md`.

## Purpose

Capture the bigger design question around `run` before more implementation work happens.

The immediate bug report was not really about one broken command. It exposed a mismatch between:

- how `run` currently behaves
- what a human naturally expects a command named `run` to mean

This doc exists so future work can start from the real product question instead of patching isolated failures.

## Current Baseline

Today `run` in `plugins/run/run.sh` does three things well:

- finds the nearest project root by manifest or task-file markers
- dispatches named local tasks such as `package.json` scripts, `just` recipes, and `make` targets
- otherwise runs a command inside the detected project environment

Examples of the current model:

- `run dev` -> `npm run dev` when `dev` is a JS script
- `run test` -> `just test` or `make test` when that target exists
- `run pytest` -> `poetry run pytest` / `uv run pytest` / similar when a Python env is detected

As of June 18, 2026, `run --list` also exists as an explicit discovery alias for bare `run`.

## Problem Statement

The current command reads like a generic project tool entrypoint, but its fallback behavior is closer to "dispatch a local task or execute a binary inside the project env."

That creates surprising results such as:

- `run install` in an npm project becoming `npm exec install`
- `run run dev` becoming `npm exec run dev`

Those results are internally consistent with the current implementation, but they are not consistent with the mental model suggested by the command name.

## Desired Direction

The likely direction is that `run` should feel like the contextual project command for the current repo.

That does not necessarily mean inventing a cross-ecosystem verb layer. The stronger interpretation is:

- `run` stands in for the primary project tool selected by context
- shorthand for local scripts/recipes/targets can still exist
- fallback behavior should distinguish between native tool subcommands and env-executed binaries

Examples of the target feel:

- `run install` should mean "ask the native project tool to install"
- `run dev` should still work as shorthand for a local task when that task exists
- `run pytest` in a Python project should still run `pytest` inside the Python env, not call a nonexistent native subcommand

## Design Constraints

- Cross-shell portability matters: bash 3.2 and zsh both need to work.
- Detection should stay manifest- or tool-driven where possible, not hardcoded to one repo layout.
- The command should stay readable and debuggable. Surprise is worse than a little verbosity.
- The repo is a public dotfiles repo, so the model should be simple enough to document in `AGENTS.md`.
- Avoid a brittle pile of special cases for individual commands.

## Discovery

`run --list` is the first discovery step. It currently lists:

- detected project root
- detected JS package manager
- detected Python env tool
- local npm scripts
- local `just` recipes
- local `make` targets

Future discovery ideas may include best-effort listing of native tool subcommands, but that is unresolved. Some tools expose subcommands cleanly via help output; others may require tool-specific parsing or a bounded amount of built-in knowledge.

## Key Open Questions

- What is the precedence order between local task shorthand, native tool subcommands, and env-executed binaries?
- How should `run` detect native subcommands without becoming fragile or slow?
- Should `runjs` remain a strict JS-only escape hatch if `run` becomes more package-manager-like?
- Should bare `run` keep listing by default forever, or should `--list` eventually become the preferred explicit form?
- How much tool-specific knowledge is acceptable before the abstraction stops earning its keep?

## Non-Goals For The Next Pass

- Do not patch isolated verbs one at a time without settling the model.
- Do not silently break current `run <script>` behavior.
- Do not turn this into a full task runner or workflow engine.
- Do not expand scope into installer or shell load-order changes unless the command design truly needs it.

## Promotion Criteria

Promote this scratch topic into an active spike when there is time to safely redesign `run` semantics without competing with more urgent shell or LifeOS work.

The first active-spike goal should be to settle the dispatch model before writing more behavior.
