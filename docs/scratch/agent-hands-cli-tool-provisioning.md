---
status: captured
---
# Agent Hands CLI tool provisioning
Have the install scripts provision the terminal tools that the linked Agent Hands capabilities need, on every platform the configs support, so a fresh machine does not need a manual tool round after setup.

What the capabilities need: `uv` (each Python capability's locked environment), `gh` (GitHub domains), `jq` and `curl` (Bash services such as Trello, Odoo and GitHub), `shasum` (Trello mutation previews), and Pandoc with `--sandbox` plus native Pango and fonts (Markdown-to-PDF rendering).

Gaps noticed while setting up a WSL (Ubuntu) machine on 2026-10-27:
- `gh` is not installed by any script; `brew-installs.sh` covers `uv`, `jq`, `pandoc` and `weasyprint`, and `dnf-installs.sh` covers Fedora.
- The Linux/WSL path depends on Homebrew. On a WSL machine without Homebrew or passwordless `sudo`, user-level installs into `~/.local/bin` worked: uv's official installer (with `UV_NO_MODIFY_PATH=1`, since the shell rc files are links into this repo) and the checksummed `gh` and Pandoc release tarballs. Ubuntu already had Pango and DejaVu fonts. There is no `apt` path.
- Native Windows only gets Tabby setup from `windows-tabby.ps1`; Git, `gh`, `uv` and Pandoc are not provisioned, and Windows PowerShell 5.1's `New-Item -ItemType SymbolicLink` needs elevation even with Developer Mode, while Python's `os.symlink` does not.
- `symlinks.sh` and the Agent Hands linkers have no Windows counterpart in the install scripts; Windows skill links were made by hand with the same selection.
