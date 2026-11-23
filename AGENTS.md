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
These rules are personal rather than repo-specific, so they also live in [agents/AGENTS.global.md](agents/AGENTS.global.md), which the installer symlinks to `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` and which therefore applies in every repo on this machine. The text below is a verbatim duplicate, kept so this file reads completely on its own. **Edit both, or neither** — the repo copy silently wins when they disagree.

Do not hard-wrap prose in Markdown, comments, docs, or examples. Let editors handle soft wrapping. Preserve paragraphs as single lines unless line breaks carry meaning, such as lists, tables, code blocks, quoted text, frontmatter, or an existing semantic-line-break style.

Avoid reflow-only diffs. When editing prose, change the smallest relevant span instead of rewrapping neighboring paragraphs.

When touching existing Markdown or prose, apply this preferred style to the paragraph, section, or example being edited so files converge over time. Do not mass-reformat untouched sections just to normalize style unless the user asks for a cleanup pass.

Prefer compact Markdown heading spacing in hand-authored docs. Put no blank line between a heading and the content it introduces, and none between adjacent headings. This file is written that way; match it.

Keep the blank line between paragraphs. In Markdown a single newline is a soft break, not a paragraph break, so paragraphs genuinely need one. Only the lines around headings are optional, and both forms render identically — this is a source-readability choice, not a rendering one.

Let explicit project tooling win when a formatter or linter requires a different layout. `markdownlint`'s MD022 wants blank lines around headings and can be switched off per repo (`{"MD022": false}`, or an inline `<!-- markdownlint-disable MD022 -->`). Prettier has no per-rule switch — it exposes options, not rules, and normalizes block spacing unconditionally; the only escapes are `.prettierignore` globs and `<!-- prettier-ignore-start -->` / `<!-- prettier-ignore-end -->` ranges. A repo that runs Prettier over Markdown will lose this style, and that is fine.

### Code Comments
Do not hard-wrap comments in code, the same as prose. Put each comment paragraph on a single line (`// …`, `# …`) and let the editor soft-wrap it.

Unlike Markdown, do not separate comment paragraphs with a blank line or an empty comment marker. Each line already carries its own marker, so consecutive comment lines already read as separate paragraphs; a blank line inside a comment block only adds noise. One paragraph is one line; the next paragraph is the next line.

The one exception is a comment block long enough to carry distinct titled sections, where a blank line may separate one section from the next. Reach for it rarely — a comment block that needs internal section breaks usually signals over-commenting.

## Where things go
| Change | Location |
| --- | --- |
| New alias / shell function | a topic module (e.g. `movement/`, `git/`) or an authored plugin under `plugins/`, then source it from [load-shell-modules.sh](load-shell-modules.sh) |
| `PATH` edit / env-manager init | [path.sh](path.sh) |
| Package to install | [install-script/functions/brew-installs.sh](install-script/functions/brew-installs.sh) (mac/linuxbrew) or [dnf-installs.sh](install-script/functions/dnf-installs.sh) (Fedora) |
| New dotfile symlinked into `$HOME` | [install-script/functions/symlinks.sh](install-script/functions/symlinks.sh) |
| Project workflow procedure | `project-workflows/<skill-name>/SKILL.md`, with target settings in `docs/project-workflows.toml` and configs-specific authority here |
| Wireframing procedure (page structure, exploration, promotion, presentation) | `wireframe-workflows/<skill-name>/SKILL.md`; the collection is new, so see its [README](wireframe-workflows/README.md) for status |
| General review, authoring, or skill-maintenance procedure | `general-skills/<skill-name>/SKILL.md`; see [current collection](general-skills/README.md) |
| Cross-repo agent preference | [agents/AGENTS.global.md](agents/AGENTS.global.md) — never repo-specific facts |
| Portable service/tool capability | `agent-hands/<skill-name>/SKILL.md`; invoke each capability through its documented native entrypoint |
| Portable service documentation | `agent-hands/docs/` and `agent-hands/TODO.md`; configs keeps shell, installer, general workflow and personal LifeOS handoff history |
| OS-conditional logic | branch on `OS_TYPE` (`mac \| fedora \| nixos \| wsl \| linux \| unknown`) |
| NixOS packages | [nixos/configuration.nix](nixos/configuration.nix) |
| Active work coordination | [TODO.md](TODO.md) |
| Spike process / active spike docs | `project-workflows/run-project-spike/SKILL.md`, then [docs/active-spikes/](docs/active-spikes/)`<topic>.md` + `<topic>.todo.md` |
| Contribution coordination | `project-workflows/coordinate-project-contribution/SKILL.md`; human-directed scope, separate agent-owned spikes and reviewable contributions from atomic commits |
| Committing work as an agent | `project-workflows/commit-work/SKILL.md`, policy in [BOUND-COMMITS](docs/agent-policies/BOUND-COMMITS-preserve-scoped-local-checkpoints.md) |
| Agent obligations | [Agent policy index](docs/agent-policies/policy.index.md) |
| Human setup guidance | [docs/policies/](docs/policies/) |
| Rough or historical notes | [docs/scratch/](docs/scratch/) (not authoritative), [docs/archive/](docs/archive/) (historical, not current rules) |
| Save a possibility or park a subject | [capture-for-later](project-workflows/capture-for-later/SKILL.md), using an individual subject note in `docs/scratch/` |
| Kaizen incident learning | [log-kaizen](general-skills/log-kaizen/SKILL.md) for capture and [improve-agent-workflows](general-skills/improve-agent-workflows/SKILL.md) for review; records live in configured private stores, never this public repo |

## Docs workflow
Policies describe current rules, defaults, procedures, exceptions, and useful rationale. Revise them directly; Git preserves their evolution. Keep development chronology and abandoned alternatives in Git or archived spike notes rather than accumulating immutable ADRs. No fixed Context / Decision / Consequences format is required.

Use [TODO.md](TODO.md) as the short coordination map. Use active spike docs when a body of work needs shared context, taste, constraints, or implementation history. Scratch docs are non-authoritative. New capture notes use `status: captured` or `status: parked` and can contain just one sentence; no proposal or task list is required. Capture belongs in the owning project; update related existing material rather than duplicating it. Archived docs are historical context; verify current guidance in maintained docs or the current implementation. Follow the spike skill for explicit attention markers and closure navigation.

Spikes earn their keep here because `configs/` is both personal and portable. A change often has to answer more than "does it work?" — it has to fit the shell load order, stay safe for a public repo, avoid secrets, remain idempotent across machines, and not slow down startup. That is more context than a ticket carries.

Authority ladder: `AGENTS.md`, `README.md`, and current policies define durable repo rules; `project-workflows/run-project-spike/SKILL.md` defines the spike process; active spike docs guide the current theme of work; `TODO.md` coordinates what is active and what is next.

## Skills workflow
Project workflows live in the independent [project-workflows/](project-workflows/README.md) submodule. This is the canonical maintenance/global installation, so the workflow submodule uses shared `main` with neutral configuration. Configs needs no workflow adaptation branch. Pinned consumers use identical shared source with project-owned configuration outside the package; deliberate source experiments need their own reviewed scope. The containing configs repository uses canonical `master` and one branch per computer: `morris` for the Mac and `lovelace-homelab` for the homelab. Follow the [machine-branch reconciliation procedure](README.md#canonical-and-machine-branches); submodule branches and exact pins remain independent. The parent Git pin records the exact adopted revision. Read the project-owned [project-workflows.toml](docs/project-workflows.toml) for configs targets and document locations. This canonical maintenance/global checkout uses the canonical exceptional-update route rather than the ordinary detached-consumer helper. The complete project procedures live directly under the submodule root. `capture-for-later` is the sole skill for saving possibilities and parked subjects. Use [setup-project-workflows](project-workflows/setup-project-workflows/SKILL.md) for adoption/docs setup and [update-project-workflows](project-workflows/update-project-workflows/SKILL.md) for ancestry-aware updates that preserve local differences.

General procedures live independently in [general-skills/](general-skills/README.md). Source ownership, global client installation, and project adoption are separate. [Setup Project Workflows](project-workflows/setup-project-workflows/SKILL.md) and [Update Project Workflows](project-workflows/update-project-workflows/SKILL.md) own current routing and maintenance. The [workflow reconciliation history](docs/archive/workflow-reconciliation.todo.md#ready-for-human-qa) records accepted ordinary macOS client use; distinct remaining client questions stay in [TODO](TODO.md#later). For Agent Hands, see [selective skill installation](agent-hands/docs/archive/selective-skill-installation.todo.md) and [runtime documentation](agent-hands/README.md#runtimes). Temporary old source routes preserve existing references; new routing should use the actual owners. The [closed modular distribution spike](docs/archive/modular-skill-distribution.md) records extraction and assigns remaining client/platform checks to their maintained owners. Both child repositories have public baselines. The retired configs workflow adaptation is preserved by the Project Workflows tag `archive/project-configs-2026-10-26`. The native command cutover removes the legacy launcher and guides. Publish reviewed child revisions before containing pins. Ongoing syncing follows the [machine-branch procedure](README.md#canonical-and-machine-branches); the [Morris reconciliation history](docs/archive/morris-reconciliation.md) records the completed local migration and selected delivery.

The installer exposes selected global Codex skills with explicit symlink calls in
[symlinks.sh](install-script/functions/symlinks.sh). Keep that list as simple direct
`create_symlink_if_needed` calls, matching the rest of the dotfile symlink style. Do not add an
allowlist parser unless the manual list becomes genuinely painful.

## Agent policies
Read the project-owned [policy index](docs/agent-policies/policy.index.md), select the applicable adopted policies, and load their complete prerequisite closure once. Proposals and retired records are non-operative. The adopted kernel owns policy adoption, identity/history and dependency loading; skills own procedures under those obligations. Package updates do not adopt or replace these project-owned copies.

## Git and commits
[BOUND-COMMITS](docs/agent-policies/BOUND-COMMITS-preserve-scoped-local-checkpoints.md) owns agent checkpoint, history and publication obligations; [Commit Work](project-workflows/commit-work/SKILL.md) owns the procedure. Routine scoped local commits are permitted. Never push under the standing policy, add co-author trailers, sweep unrelated changes or rewrite history on your own authority. Honor explicit user decisions and review holds within their scope.

The user's `gitall` and `gitcommit` helpers can sweep unrelated work through the shared index. Do not run or change them while an agent is working. The user's `gitpush` helper remains unchanged.

## Secrets and local env
[PROTECT-SECRETS](docs/agent-policies/PROTECT-SECRETS-keep-private-inputs-out-of-git.md) owns agent privacy and secret-handling obligations. [Secrets and local environment setup](docs/policies/0001-secrets-and-local-env.md) retains human setup examples. Actual private files must be ignored before use; tracked examples contain synthetic values. Tool-specific private storage and recovery remain with their owners.

The installed global instructions are linked to this public repository. Client memory features that write through that link can publish private material later; do not use them to save private context. Private agent memory outside the checkout remains separate. Changing the installation arrangement requires its own authorized work.

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
