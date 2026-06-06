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

## Where things go

| Change | Location |
| --- | --- |
| New alias / shell function | a topic module (e.g. `movement/`, `git/`) or an authored plugin under `plugins/`, then source it from [load-shell-modules.sh](load-shell-modules.sh) |
| `PATH` edit / env-manager init | [path.sh](path.sh) |
| Package to install | [install-script/functions/brew-installs.sh](install-script/functions/brew-installs.sh) (mac/linuxbrew) or [dnf-installs.sh](install-script/functions/dnf-installs.sh) (Fedora) |
| New dotfile symlinked into `$HOME` | [install-script/functions/symlinks.sh](install-script/functions/symlinks.sh) |
| OS-conditional logic | branch on `OS_TYPE` (`mac \| fedora \| nixos \| wsl \| linux \| unknown`) |
| NixOS packages | [nixos/configuration.nix](nixos/configuration.nix) |
| Active work coordination | [TODO.md](TODO.md) |
| Spike process / active spike docs | [docs/how-to-spike.md](docs/how-to-spike.md), then `docs/<topic>.md` + `docs/<topic>.todo.md` |
| Durable decision record | [docs/decisions/](docs/decisions/) |
| Rough or historical notes | [docs/scratch/](docs/scratch/), [docs/archive/](docs/archive/) |

## Docs workflow

Use [TODO.md](TODO.md) as the short coordination map. Use active spike docs when a body
of work needs shared context, taste, constraints, or implementation history. Scratch docs
are non-authoritative. Archived docs are historical context, not current rules, unless a
durable doc still agrees with them.

Authority ladder: `AGENTS.md`, `README.md`, and active decision records define durable
repo rules; `docs/how-to-spike.md` defines the spike process; active spike docs guide the
current theme of work; `TODO.md` coordinates what is active and what is next.

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
env (`poetry`/`uv`/`pixi`/`pipenv run`) or via `<pm> exec`. `run` with no args lists what's
runnable. `runjs` forces the JS package manager (for monorepos where JS and a Python env
share a root). First-arg tab completion (npm scripts / just recipes / make targets) lives in
`completion.zsh` and `completion.bash`. Keep new ecosystems detection-driven (lockfile /
manifest), not hardcoded.

The plugin is first-party (authored here), unlike the git-submodule plugins in `plugins/`;
it is intentionally not registered in `.gitmodules`.
