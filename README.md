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
- **Agent skills:** project workflow seeds currently live in `skills/`; independently usable review, authoring, and derived-skill maintenance procedures live in [general-skills/](general-skills/README.md). Selected skills are symlinked into Codex and Claude by `symlinks.sh`.

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

The `log-skills-feedback` entry is removed. A temporary `skills/kaizen` route preserves old source links while consumers migrate. Removing current files does not remove past Git versions. Proposed rule changes still require user approval.

## Troubleshooting
### Prompts look broken
- **In VS Code terminal:** Normal - uses simplified prompt for compatibility
- **In regular terminal:** Ensure Powerlevel10k fonts are installed (see `plugins/powerlevel10k/font.md`)

### Homebrew not found after install
Run `source ~/.zshrc` or open a new terminal session.
