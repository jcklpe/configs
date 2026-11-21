# Configs
Portable dotfiles and shell configuration that works across macOS, Linux, and NixOS. Clone once, run anywhere.

## Canonical and machine branches
`master` is the canonical branch. Each computer uses its own branch: `morris` for the Mac and `lovelace-homelab` for the homelab. Keep their shared configuration aligned: review computer-local changes upstream into `master`, then bring accepted canonical changes back down to each machine branch. These branches isolate incidental edits and make reconciliation explicit; they are not intended as permanently separate configurations. A branch name does not change the machine's hostname.

Keep the existing canonical branch name `master`. Do not rename it or delete/reset machine branches as part of routine reconciliation.

The guarded Rust initialization in `path.sh` is common: it sources `~/.cargo/env` only if readable, installs nothing, and does nothing when that file is absent.

### Reconciliation procedure
1. Inspect current local and remote heads, uncommitted work, and both directions of the commit/content diff before reconciliation. Use an isolated checkout when another agent or computer is active; do not switch, reset, stash or merge someone else's active checkout.
2. Review proposed upstream changes individually. Promote only the intended, validated common changes to `master`; do not merge a computer branch wholesale when it includes unrelated, private or unreviewed history. Keep credentials, runtime caches and private configuration out of every published branch. Branch separation is not a privacy boundary.
3. Validate affected configuration and its dependencies. Keep necessary machine-specific differences small and explicit, and retain unverified experiments as such rather than silently promoting them.
4. Bring reviewed canonical changes into each machine branch without rewriting history. Preserve local work, inspect conflicts and concurrent changes, and verify the intended shared files agree. Creating a branch does not synchronize a dirty checkout or update its submodules; independent repositories retain their own branches and exact pins.
5. Publish only within explicit owner authorization and after reviewing the complete outgoing range. Recheck remote heads before writing, stop on stale state, use normal fast-forward updates and verify the resulting remote commits. Never force-push to make branches match.

Published branch synchronization and live-machine deployment are separate. A machine with ongoing work should finish or safely checkpoint it before integrating canonical updates.

The current `lovelace-homelab` branch contains opt-in Tabby/Quake/Nix experiments. Keep their documented unverified runtime/build checks visible until tested. Reconciliation must not silently promote these experiments to the canonical branch.

## What Gets Installed
- **Homebrew** (package manager)
- **zsh** with Powerlevel10k prompt
- **Command-line tools:** eza, jump, mc (Midnight Commander), ranger
- **Symlinked configs:** .zshrc, .bashrc, .gitignore_global, etc.

All install scripts are **idempotent** - safe to run multiple times.

## OS-Specific Features
**macOS:**
- Homebrew installed to `/opt/homebrew` (Apple Silicon)

**Linux / Fedora:**
- Homebrew support via linuxbrew
- Optional torch activation (if ~/torch exists)

**NixOS:**
- Packages managed via `nixos/configuration.nix`
- Homebrew skipped — nix handles everything
- Run the NixOS installer first to generate hardware config, then run `linux-install.sh`

## Tools
- **Shell:** [zsh](https://www.zsh.org/) (primary), bash (fallback)
- **Terminal:** [Tabby](https://tabby.sh/), [WezTerm](https://wezfurlong.org/wezterm/)
- **Editor:** [VS Code](https://code.visualstudio.com/), [Micro](https://micro-editor.github.io/)
- **Agent skills:** project procedures live in the [project-workflows submodule](project-workflows/README.md); independently usable review, authoring, and derived-skill maintenance procedures live in [general-skills/](general-skills/README.md). Selected skills are symlinked into Codex and Claude by `symlinks.sh`.
- **Agent integrations:** [setup-agent-hands](agent-hands/setup-agent-hands/SKILL.md) is the starting point for restoring service capabilities, and each service's `setup-*` guide owns its MCP or CLI setup and verification. Connections and credentials remain local; installing a skill does not connect an account.

## Windows Tabby
Windows Tabby reads `%APPDATA%\tabby\config.yaml`, separately from the Linux config inside WSL. Close Tabby, then run this in an administrator PowerShell from the Windows configs checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-script\windows-tabby.ps1 -ReplaceExisting
```

The script backs up an existing config before linking it to `tabby/config.windows.yaml`, installs the repo's regular/bold FiraCode Nerd Font Mono for the Windows user, and is safe to rerun. Windows Developer Mode also permits creating the symlink without elevation. The Windows config keeps the Linux theme and shortcuts and starts the default WSL distribution in its Linux home directory with `wsl.exe --cd ~`. This avoids translating an inherited Windows working directory, including virtual drives. WSL should already be working; zsh also needs its startup links and the repo plugin submodules initialized. Installing zsh alone does not connect the dotfiles. Run this focused script rather than the full Linux symlink installer to configure the native Windows app.

## Project Documentation
Current agent obligations live in the [agent policy index](docs/agent-policies/policy.index.md); human secrets/setup guidance remains in [docs/policies/](docs/policies/). Portable service policies, spikes and former LifeOS tooling history live with [Agent Hands](agent-hands/TODO.md). Revise policies directly; Git and archived spike notes retain their history. [TODO.md](TODO.md) indexes active work, and [AGENTS.md](AGENTS.md) defines the documentation workflow.

## Private Kaizen
The [log-kaizen](general-skills/log-kaizen/SKILL.md) skill captures private workflow incidents. [improve-agent-workflows](general-skills/improve-agent-workflows/SKILL.md) checks relevant evidence, prepares proposals, and applies authorized improvements. Global instructions activate the appropriate procedure during ordinary work; neither is a background service. The installer exposes both to Codex and Claude as replacements for the prior combined Kaizen skill. Projects can adopt them separately and declare their own private stores.

Keep records outside this public repository. Each skill's adjacent `.env.example` defines `KAIZEN_GLOBAL_CURRENT` and `KAIZEN_GLOBAL_INCIDENTS`; actual values belong in an ignored `.env`. `KAIZEN_ENV_FILE` can select a shared env file explicitly. Existing `KAIZEN_CONFIG`/XDG JSON configuration remains a migration fallback when no env source is selected or present. See either skill for exact precedence, privacy checks, and connector-only access. The installer does not create private records or copy configuration. Missing access is reported rather than replaced with a public fallback.

The `log-skills-feedback` and `skills/kaizen` compatibility entries are removed; current callers use the capture/review owners in `general-skills`. Removing current files does not remove past Git versions. Proposed rule changes still require user approval.

## Troubleshooting
### Prompts look broken
- **In VS Code terminal:** Normal - uses simplified prompt for compatibility
- **In regular terminal:** Ensure Powerlevel10k fonts are installed (see `plugins/powerlevel10k/font.md`)

### Homebrew not found after install
Run `source ~/.zshrc` or open a new terminal session.

## Skill package checkouts
This repository pins [agent-hands](agent-hands/README.md) and `project-workflows/` independently. Agent Hands contains the extracted service capabilities and Markdown-to-PDF renderer; its README identifies the current boundaries and dependencies. Invoke capability-owned native entrypoints directly; private consumers own multi-service orchestration. Provider-owned configuration stays in its existing private storage; private workflow composition belongs to the consumer. Dotfile installation preserves existing Agent Hands links and directs new setup to [setup-agent-hands](agent-hands/setup-agent-hands/SKILL.md). Individual service setup skills offer optional global links for only the requested capabilities and clients; this installer does not select services or provision their runtimes. Near the end, both main installers print an Agent Hands banner and setup pointer. If its setup guide is still missing, an interactive `[y/N]` prompt offers a scoped checkout initialization; declining, EOF or non-interactive execution leaves it unchanged. The earlier general submodule step excludes Agent Hands from initialization and updates it only when its checkout already exists. A missing checkout reaches the prompt untouched; an existing checkout retains ordinary update behavior and receives an informational notice. The `project-workflows/` checkout is the canonical maintenance/global installation on shared `main`, with neutral templates, no runtime project configuration, and complete procedures directly at its root. Configs-specific settings live in [docs/project-workflows.toml](docs/project-workflows.toml); instructions and actual documents stay in this parent repository. Pinned consumers use the unchanged shared package with their own configuration. The outer configs repository uses canonical `master` and the selected computer branch, as described in [Canonical and machine branches](#canonical-and-machine-branches). Agent Hands independently pins its unchanged shared workflow package. Use [setup-project-workflows](project-workflows/setup-project-workflows/SKILL.md) and [update-project-workflows](project-workflows/update-project-workflows/SKILL.md) for adoption and reconciliation. Global client links select these procedures without installing general or service skills into every adopting project. `capture-for-later` is the sole skill for saving individual captured or parked scratch notes. Existing notes and other project checkouts are not migrated by installation.

Project Workflows, Agent Hands and Wireframe Workflows have published workflow rollout revisions. Restore their exact recorded pins with `git submodule update --init --recursive`; this canonical maintenance/global workflow checkout uses shared main for source maintenance. Project settings and policies stay outside the common package. Earlier adaptation history is preserved by named Project Workflows archive tags, including `archive/project-configs-2026-10-26`. The [Morris reconciliation task record](docs/active-spikes/morris-reconciliation.todo.md) tracks reviewed child-first publication and fresh recursive retrieval. The user accepts the homelab reconciliation as handled; its separate experiment history is preserved. Other consumer migrations remain separately selected work.

### Retired local service tree
The previous `lifeos-tools/` tree and shared-runtime installer are removed after the [verified cutover](docs/archive/modular-skill-distribution.todo.md). Git preserves the tracked originals; reconciled untracked material and prior cutover metadata were moved to recoverable local Trash, with restoration instructions in that bundle. Active tools must not load recovery material. Provider configuration and authentication remain at their existing Agent Hands owners.
