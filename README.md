# Configs
Portable dotfiles and shell configuration that works across macOS, Linux, and NixOS. Clone once, run anywhere.

## Canonical and machine branches
`master` is this repository's canonical mainline; “main” means that role, not a second branch named `main`. Machine branches such as `lovelace-homelab` carry only machine-specific configuration and experiments. Common fixes belong upstream on `master`, then flow back down to every maintained machine branch. A branch name does not change the machine's hostname.

The guarded Rust initialization in `path.sh` is common: it sources `~/.cargo/env` only if readable, installs nothing, and does nothing when that file is absent.

### Reconciliation procedure
1. Inspect remote heads and both directions of the commit/content diff regularly and before starting or finishing machine work. Use an isolated clone or worktree; never switch, reset, stash, or merge someone else's active checkout.
2. Classify changes as common, machine-specific, experimental, or private. Promote only reviewed common changes to `master` in a focused commit, not by merging an entire machine branch. Keep credentials, hardware identity, local history backups, and unvalidated machine experiments out of common changes.
3. Validate affected shells/configs and applicable tests. Record unavailable checks honestly. In particular, an unbuilt Nix/Home Manager experiment is not validated merely because it is version-controlled.
4. Merge the current canonical commit into each known maintained machine branch without rewriting its history. Resolve overlapping edits explicitly; stop for uncertain conflicts or concurrent changes. Verify the canonical commit is an ancestor, retained machine changes are intentional, and shared files agree.
5. Publish only with the owner's explicit authorization, respecting repository policies. Recheck remote heads immediately before updating; reject stale heads rather than force-pushing. Verify the published SHA and report conflicts, missing machine branches, and deployment work still pending.

Published branch synchronization and live-machine deployment are separate. An agent currently working on another computer should finish or safely checkpoint its work first, fetch the canonical update, then create or update its machine branch and integrate reviewed common changes. Do not reset an active checkout just to make its status match the remote. No other machine branch should be inferred from legacy feature or dependency-update branches.

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
Current configs guidance lives in [docs/policies/](docs/policies/). Portable service policies, spikes and former LifeOS tooling history live with [Agent Hands](agent-hands/TODO.md). Revise policies directly; Git and archived spike notes retain their history. [TODO.md](TODO.md) indexes active work, and [AGENTS.md](AGENTS.md) defines the documentation workflow.

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
This repository pins [agent-hands](agent-hands/README.md) and `project-workflows/` independently. Agent Hands contains the extracted service capabilities and Markdown-to-PDF renderer; its README identifies the current boundaries and dependencies. Invoke capability-owned native entrypoints directly; private consumers own multi-service orchestration. Provider-owned configuration stays in its existing private storage; private workflow composition belongs to the consumer. Dotfile installation preserves existing Agent Hands links and directs new setup to [setup-agent-hands](agent-hands/setup-agent-hands/SKILL.md). Individual service setup skills offer optional global links for only the requested capabilities and clients; this installer does not select services or provision their runtimes. Near the end, both main installers print an Agent Hands banner and setup pointer. If its setup guide is still missing, an interactive `[y/N]` prompt offers a scoped checkout initialization; declining, EOF or non-interactive execution leaves it unchanged. The earlier general submodule step excludes Agent Hands from initialization and updates it only when its checkout already exists. A missing checkout reaches the prompt untouched; an existing checkout retains ordinary update behavior and receives an informational notice. The `project-workflows/` checkout is the canonical maintenance/global installation on shared `main`, with neutral `workflow.toml` defaults and complete procedures directly at its root. Configs-specific settings live in [docs/workflow.toml](docs/workflow.toml); instructions and actual documents stay in this parent repository. Pinned consumers use the unchanged shared package with their own configuration. The outer configs branch remains `master`. Agent Hands independently pins its unchanged shared workflow package. Use [setup-project-workflows](project-workflows/setup-project-workflows/SKILL.md) and [update-project-workflows](project-workflows/update-project-workflows/SKILL.md) for adoption and reconciliation. Global client links select these procedures without installing general or service skills into every adopting project. `capture-for-later` is the sole skill for saving individual captured or parked scratch notes. Existing notes and other project checkouts are not migrated by installation.

Project Workflows, Agent Hands and Wireframe Workflows have published workflow rollout revisions. Restore their exact recorded pins with `git submodule update --init --recursive`; this canonical maintenance/global workflow checkout uses shared main for source maintenance. Project settings and policies stay outside the common package. Earlier adaptation history is preserved by named Project Workflows archive tags, including `archive/project-configs-2026-10-26`. See [Workflow Reconciliation](docs/active-spikes/workflow-reconciliation.md) for that separate work.

### Retired local service tree
The previous `lifeos-tools/` tree and shared-runtime installer are removed after the [verified cutover](docs/active-spikes/modular-skill-distribution.todo.md). Git preserves the tracked originals; reconciled untracked material and prior cutover metadata were moved to recoverable local Trash, with restoration instructions in that bundle. Active tools must not load recovery material. Provider configuration and authentication remain at their existing Agent Hands owners.
