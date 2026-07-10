# AGENTS.md
Personal dotfiles + setup scripts for macOS, Linux (Fedora/generic), NixOS, and WSL.
Clone to a new machine, run the installer, and the shell/editor/terminal are configured
via symlinks back into this repo. `CLAUDE.md` is a symlink to this file.

## How the shell config loads
Both shells source the same files, in this order. Read these before changing load order:

1. **[init.sh](init.sh)** — sets `CONFIGS` (repo root, auto-detected) and `PLUGINS`,
   sources [detect-os.sh](install-script/functions/detect-os.sh) to export `OS_TYPE`,
   and sets up the Homebrew environment.
2. **[path.sh](path.sh)** — `PATH` edits and environment managers (fnm, pipx, pixi).
3. **[load-shell-modules.sh](load-shell-modules.sh)** — sources the topic modules:
   [movement/movement.sh](movement/movement.sh) (listing/navigation),
   [git/git.sh](git/git.sh), and the `run` dispatcher
   ([plugins/run/run.sh](plugins/run/run.sh)) with its shell-specific completion.

Entry points: [zsh/zshrc](zsh/zshrc) (primary) and [bash/bashrc.sh](bash/bashrc.sh) (fallback),
symlinked to `~/.zshrc` / `~/.bashrc` by the installer.

## Conventions — match these
- **Cross-shell.** Anything sourced from `load-shell-modules.sh`, `init.sh`, or `path.sh`
  runs in **both bash and zsh**. Keep it portable:
  - Target **bash 3.2** (the macOS system bash). No associative arrays (`declare -A`),
    no `${var,,}`, no `mapfile`/`readarray`.
  - **Never rely on word-splitting an unquoted variable** — zsh does not split by default.
    Pass multi-word command prefixes as separate literal args (see `_run_js` in
    [plugins/run/run.sh](plugins/run/run.sh)), don't build a `"corepack pnpm"` string and splat it.
  - zsh-only behavior must be guarded (see the eza overrides in `movement.sh`).
- **Guard optional tools** with `command -v <tool> >/dev/null 2>&1` and provide a
  fallback (e.g. `lk` falls back from `eza` to `ls`).
- **Section headers** use the `##- ` comment prefix.
- **Idempotency is required** for install scripts — they're re-run on every machine and
  must be safe to run repeatedly. Check-before-write (see `create_symlink_if_needed`).

## Markdown And Prose Style
Do not hard-wrap prose in Markdown, comments, docs, or examples. Let editors handle soft wrapping. Preserve paragraphs as single lines unless line breaks carry meaning, such as lists, tables, code blocks, quoted text, frontmatter, or an existing semantic-line-break style.

Avoid reflow-only diffs. When editing prose, change the smallest relevant span instead of rewrapping neighboring paragraphs.

When touching existing Markdown or prose, apply this preferred style to the paragraph, section, or example being edited so files converge over time. Do not mass-reformat untouched sections just to normalize style unless the user asks for a cleanup pass.

Prefer compact Markdown heading spacing in hand-authored docs. Put no blank line between a heading and the content it introduces, and none between adjacent headings. This file is written that way; match it.

Keep the blank line between paragraphs. In Markdown a single newline is a soft break, not a paragraph break, so paragraphs genuinely need one. Only the lines around headings are optional, and both forms render identically — this is a source-readability choice, not a rendering one.

Let explicit project tooling win when a formatter or linter requires a different layout. `markdownlint`'s MD022 wants blank lines around headings and can be switched off per repo (`{"MD022": false}`, or an inline `<!-- markdownlint-disable MD022 -->`). Prettier has no per-rule switch — it exposes options, not rules, and normalizes block spacing unconditionally; the only escapes are `.prettierignore` globs and `<!-- prettier-ignore-start -->` / `<!-- prettier-ignore-end -->` ranges. A repo that runs Prettier over Markdown will lose this style, and that is fine.

## Where things go
| Change | Location |
| --- | --- |
| New alias / shell function | a topic module (e.g. `movement/`, `git/`) or an authored plugin under `plugins/`, then source it from [load-shell-modules.sh](load-shell-modules.sh) |
| `PATH` edit / env-manager init | [path.sh](path.sh) |
| Package to install | [install-script/functions/brew-installs.sh](install-script/functions/brew-installs.sh) (mac/linuxbrew) or [dnf-installs.sh](install-script/functions/dnf-installs.sh) (Fedora) |
| New dotfile symlinked into `$HOME` | [install-script/functions/symlinks.sh](install-script/functions/symlinks.sh) |
| Reusable agent-neutral skill | `skills/<skill-name>/SKILL.md` |
| Tool-specific skill | beside the tool, e.g. `lifeos-tools/skills/<skill-name>/SKILL.md` |
| OS-conditional logic | branch on `OS_TYPE` (`mac \| fedora \| nixos \| wsl \| linux \| unknown`) |
| NixOS packages | [nixos/configuration.nix](nixos/configuration.nix) |
| Active work coordination | [TODO.md](TODO.md) |
| Spike process / active spike docs | `skills/run-project-spike/SKILL.md`, then `docs/<topic>.md` + `docs/<topic>.todo.md` |
| Committing work as an agent | `skills/commit-work/SKILL.md`, policy in [docs/decisions/0003-agent-commit-policy.md](docs/decisions/0003-agent-commit-policy.md) |
| Durable decision record | [docs/decisions/](docs/decisions/) |
| Rough or historical notes | [docs/scratch/](docs/scratch/), [docs/archive/](docs/archive/) |

## Docs workflow
Use [TODO.md](TODO.md) as the short coordination map. Use active spike docs when a body
of work needs shared context, taste, constraints, or implementation history. Scratch docs
are non-authoritative. Archived docs are historical context, not current rules, unless a
durable doc still agrees with them.

Spikes earn their keep here because `configs/` is both personal and portable. A change often has to answer more than "does it work?" — it has to fit the shell load order, stay safe for a public repo, avoid secrets, remain idempotent across machines, and not slow down startup. That is more context than a ticket carries.

Authority ladder: `AGENTS.md`, `README.md`, and active decision records define durable
repo rules; `skills/run-project-spike/SKILL.md` defines the spike process; active spike docs guide the
current theme of work; `TODO.md` coordinates what is active and what is next.

## Skills workflow
Use [skills/](skills/) as the version-controlled seed library for reusable, agent-neutral
`SKILL.md` workflows. These are complete enough to use globally and copy into other repos.
When a project should carry its own operating process after clone, copy the whole skill folder
into that repo's `skills/` directory and let it evolve there. Repo-local skills are project
authority; global skills are fallback seed material.

The installer exposes selected global Codex skills with explicit symlink calls in
[symlinks.sh](install-script/functions/symlinks.sh). Keep that list as simple direct
`create_symlink_if_needed` calls, matching the rest of the dotfile symlink style. Do not add an
allowlist parser unless the manual list becomes genuinely painful.

## Git and commits
Agents may commit in this repo. Agents may never push. The line is reversibility: an unpushed commit costs nothing to undo, a push cannot be taken back. See [docs/decisions/0003-agent-commit-policy.md](docs/decisions/0003-agent-commit-policy.md) for the full rule and `skills/commit-work/SKILL.md` for how.

The rules that matter most, because breaking them is silent:

- **Commit by pathspec, never stage.** `git commit -F - -- <explicit paths>`. Git's index is repo-global shared state, and this repo often has two agents in it at once — one agent's `git add` followed by another's bare `git commit` puts the first agent's files in the second's commit, with no error.
- **Never `git add -f`.** Git's own refusal to add an ignored file recommends `-f`, and `-f` then commits the secret. Run `git check-ignore -q <path>` first. See [docs/decisions/0001-secrets-and-local-env.md](docs/decisions/0001-secrets-and-local-env.md).
- **Never `--amend`, rebase, force-push, or `--no-verify`.**
- **One commit does one thing.** If the summary needs the word "and," it is two commits.

`gitall` is the user's own sweep-and-push helper and is not to be changed. It is a bare commit over the shared index, so **do not run `gitall` in this repo while an agent is working in it.**

## Secrets and local env
This repo may contain public-safe tools that use private local secrets. Real secret-bearing
files may live inside the local `configs/` working tree, but they must be ignored before
they are created or used. Commit adjacent example files with fake values.

Preferred pattern:

```text
some-tool/
  tool.sh
  .env.example              # tracked fake values
  .env                      # ignored real values
  google-token.example.json # tracked fake values
  google-token.json         # ignored real values
```

Do not commit API keys, OAuth credentials, OAuth tokens, generated private snapshots, or
private local config. Do not load secrets from global shell startup by default; tools
should load their own env/config at runtime unless a shell module explicitly documents a
different behavior.

See [docs/decisions/0001-secrets-and-local-env.md](docs/decisions/0001-secrets-and-local-env.md).

## Install model
[install-script/mac-install.sh](install-script/mac-install.sh) and
[install-script/linux-install.sh](install-script/linux-install.sh) install packages/fonts
and then call `symlinks.sh`, which links repo files into `$HOME` (and a few XDG/`.config`
paths). Configs are edited **in this repo**; the symlinks make them live. Don't copy files
into `$HOME` — symlink them.

## Validating a change
There's no test suite. To check shell changes, source the affected file in a fresh shell of
**each** kind and exercise it:

```sh
bash -c 'source ./run/run.sh && cd /some/project && run'
zsh  -c 'source ./run/run.sh && cd /some/project && run'
```

For installer changes, prefer dry inspection; they touch the real system and assume their
target OS.

## The `run` command
`run` ([plugins/run/run.sh](plugins/run/run.sh)) finds the nearest project root and dispatches:
named `package.json` scripts via the right package manager (`corepack pnpm`/`yarn`, `npm`,
`bun`), `just` recipes, and `make` targets; anything else runs inside the detected Python
env (`poetry`/`uv`/`pixi`/`pipenv run`) or via `<pm> exec`. `run` with no args or `--list`
lists what's runnable. `runjs` forces the JS package manager (for monorepos where JS and a Python env
share a root). First-arg tab completion (npm scripts / just recipes / make targets) lives in
`completion.zsh` and `completion.bash`. Keep new ecosystems detection-driven (lockfile /
manifest), not hardcoded.

The plugin is first-party (authored here), unlike the git-submodule plugins in `plugins/`;
it is intentionally not registered in `.gitmodules`.
