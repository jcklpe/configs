#!/usr/bin/env bash
set -euo pipefail

BREW_SYSTEM="/home/linuxbrew/.linuxbrew"
BREW_USER="$HOME/.linuxbrew"

# Pick whichever brew exists (prefer system brew if present)
if [ -x "$BREW_SYSTEM/bin/brew" ]; then
  BREW_PREFIX="$BREW_SYSTEM"
elif [ -x "$BREW_USER/bin/brew" ]; then
  BREW_PREFIX="$BREW_USER"
else
  BREW_PREFIX=""   # not installed yet
fi

install_brew() {
  # Only install if brew isn't present yet
  if [ -n "${BREW_PREFIX}" ]; then
    return 0
  fi

  # Modern Homebrew installer URL (Linuxbrew old URL is deprecated)
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Re-detect after install
  if [ -x "$BREW_SYSTEM/bin/brew" ]; then
    BREW_PREFIX="$BREW_SYSTEM"
  elif [ -x "$BREW_USER/bin/brew" ]; then
    BREW_PREFIX="$BREW_USER"
  else
    echo "brew install completed but brew not found in:" >&2
    echo "  $BREW_SYSTEM/bin/brew" >&2
    echo "  $BREW_USER/bin/brew" >&2
    exit 1
  fi
}

enable_brew_for_this_run() {
  local brew_bin="$BREW_PREFIX/bin/brew"
  if [ ! -x "$brew_bin" ]; then
    echo "brew binary not found at $brew_bin" >&2
    exit 1
  fi
  eval "$("$brew_bin" shellenv)"
}

setup_login_shell_zsh() {
  local zsh_bin="$BREW_PREFIX/bin/zsh"
  if [ ! -x "$zsh_bin" ]; then
    echo "brew zsh not found at $zsh_bin (skipping chsh)" >&2
    return 0
  fi

  # If brew zsh isn't in /etc/shells, chsh may fail unless we add it.
  # Only try if we have sudo.
  if ! grep -qxF "$zsh_bin" /etc/shells 2>/dev/null; then
    if command -v sudo >/dev/null 2>&1; then
      echo "Adding $zsh_bin to /etc/shells"
      echo "$zsh_bin" | sudo tee -a /etc/shells >/dev/null
    else
      echo "No sudo; cannot add $zsh_bin to /etc/shells. Skipping chsh." >&2
      return 0
    fi
  fi

  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"

  if [ "$current_shell" != "$zsh_bin" ]; then
    echo "Changing login shell to $zsh_bin"
    chsh -s "$zsh_bin"
    echo "Login shell changed. Log out/in (or reboot) for it to take effect."
  fi
}

install_brew
enable_brew_for_this_run
setup_login_shell_zsh
