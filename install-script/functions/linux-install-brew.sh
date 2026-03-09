#!/usr/bin/env bash
# Note: intentionally no set -euo pipefail — this file is sourced, not executed.
# Strict mode would kill the parent shell on any error.

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
    return 1 2>/dev/null || exit 1
  fi
}

enable_brew_for_this_run() {
  local brew_bin="$BREW_PREFIX/bin/brew"
  if [ ! -x "$brew_bin" ]; then
    echo "brew binary not found at $brew_bin" >&2
    return 1 2>/dev/null || exit 1
  fi
  eval "$("$brew_bin" shellenv)"
}

install_brew
enable_brew_for_this_run
# Note: default shell is set by linux-install.sh via chsh — not done here
