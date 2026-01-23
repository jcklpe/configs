# Configs

Portable dotfiles and shell configuration that works across macOS, Linux, and WSL. Clone once, run anywhere.

## What Gets Installed
- **Homebrew** (package manager)
- **zsh** with Powerlevel10k prompt
- **Command-line tools:** eza, jump, mc (Midnight Commander), ranger
- **Symlinked configs:** .zshrc, .bashrc, .hyper.js, .gitignore_global, etc.

All install scripts are **idempotent** - safe to run multiple times.

## OS-Specific Features

**macOS:**
- Homebrew installed to `/opt/homebrew` (Apple Silicon)

**Linux:**
- Homebrew support via linuxbrew
- Optional torch activation (if ~/torch exists)

**WSL:**
- `$WINHOME` environment variable (Windows user directory)
- `cmd` and `vscode` aliases for Windows executables
- Auto-navigation to proper home directory on login

## VS Code Terminal Integration
The config automatically detects VS Code's integrated terminal and loads a simplified prompt for compatibility. Powerlevel10k is skipped in VS Code to prevent terminal integration issues.

## Tools

- **Shell:** [zsh](https://www.zsh.org/) (primary), bash (fallback)
- **Terminal:** [Hyper](https://hyper.is/), VS Code integrated terminal
- **Editor:** [VS Code](https://code.visualstudio.com/)
- **Launcher:** [ueli](https://github.com/oliverschwendener/ueli) (macOS/Windows)

## Troubleshooting

### Prompts look broken
- **In VS Code terminal:** Normal - uses simplified prompt for compatibility
- **In regular terminal:** Ensure Powerlevel10k fonts are installed (see `plugins/powerlevel10k/font.md`)

### Homebrew not found after install
Run `source ~/.zshrc` or open a new terminal session.

### WSL: Wrong home directory on login
The config automatically detects this and navigates to the correct directory in `zprofile`.
