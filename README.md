# Configs
Portable dotfiles and shell configuration that works across macOS, Linux, and NixOS. Clone once, run anywhere.

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
- **Agent integrations:** [client selections and extras](agents/integrations.md) link to the portable [MCP sourcing catalog](agent-hands/mcp-integrations.md). Connections and credentials remain local; installing a skill does not connect an account.

## Windows Tabby
Windows Tabby reads `%APPDATA%\tabby\config.yaml`, separately from the Linux config inside WSL. Close Tabby, then run this in an administrator PowerShell from the Windows configs checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-script\windows-tabby.ps1 -ReplaceExisting
```

The script backs up an existing config before linking it to `tabby/config.windows.yaml`, installs the repo's regular/bold FiraCode Nerd Font Mono for the Windows user, and is safe to rerun. Windows Developer Mode also permits creating the symlink without elevation. The Windows config keeps the Linux theme and shortcuts and starts the default WSL distribution in its Linux home directory with `wsl.exe --cd ~`. This avoids translating an inherited Windows working directory, including virtual drives. WSL should already be working; zsh also needs its startup links and the repo plugin submodules initialized. Installing zsh alone does not connect the dotfiles. Run this focused script rather than the full Linux symlink installer to configure the native Windows app.

## Project Documentation
Current project guidance lives in [docs/policies/](docs/policies/). Revise policies directly; Git and archived spike notes retain their history. [TODO.md](TODO.md) indexes active work, and [AGENTS.md](AGENTS.md) defines the documentation workflow.

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
This repository pins [agent-hands](agent-hands/README.md) and `project-workflows/` independently. Agent Hands contains the extracted service capabilities and Markdown-to-PDF renderer; its README identifies the current boundaries and dependencies. The optional `lifeos` launcher lives in `agent-hands/bin/`, with adapters and routing guides in `agent-hands/compat/lifeos/`. Provider-owned configuration stays adjacent to its existing authorization skills; private workflow composition belongs to the consumer. The installer exposes the selected native service skills and compatibility guides without provisioning a shared runtime. The workflow collection keeps its project configuration on `project/configs` inside `project-workflows/`; actual configs documentation remains in the parent repository. The outer configs branch remains `master`. Agent Hands independently pins its own nested workflow adaptation on `project/agent-hands`. Use [setup-project-workflows](project-workflows/skills/setup-project-workflows/SKILL.md) and [update-project-workflows](project-workflows/skills/update-project-workflows/SKILL.md) for adoption and reconciliation. Global client links select these procedures without installing general or service skills into every adopting project.

Both child repositories and the workflow project refs have published baselines; fresh public recursive retrieval of the unchanged nested workflow pin was verified. The compatibility cutover adds a local Agent Hands checkpoint that must be published separately before publishing its containing pin. The outer configs checkpoint remains unpublished because its outgoing history includes unrelated earlier work; child publication does not make that outer tree available. `git submodule update --init --recursive` restores recorded revisions, and the intended workflow project branch should be selected before editing the child. See [Workflow Reconciliation](docs/active-spikes/workflow-reconciliation.md) for the current verification and publication boundary.

### Retired local service tree
The previous `lifeos-tools/` tree is being retired through the [modular migration record](docs/active-spikes/modular-skill-distribution.todo.md). Local recovery material belongs under the ignored `.local-retired/` root and must never be loaded by active tools or committed. Restore only under the recorded recovery procedure after checking for newer work; provider credentials remain at their existing Agent Hands owners.
