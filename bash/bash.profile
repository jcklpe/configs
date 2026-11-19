# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# Everything useful is put in .bashrc but this allows me to selectively trigger scripts only at shell start up

# Initialize CONFIGS, PLUGINS, and OS_TYPE (must come first)
# Follow the entrypoint symlink so a side-by-side checkout loads its own init.
if [ -n "${BASH_VERSION:-}" ]; then
    _configs_bootstrap() {
        local entry="$1" target root hops=0
        while [ -L "$entry" ]; do
            [ "$hops" -lt 40 ] || return 1
            hops=$((hops + 1))
            target="$(readlink "$entry")" || return 1
            case "$target" in
                /*) entry="$target" ;;
                *) entry="$(dirname "$entry")/$target" ;;
            esac
        done
        root="$(cd -P "$(dirname "$entry")/.." && pwd)" || return 1
        source "$root/init.sh"
    }
    _configs_bootstrap "${BASH_SOURCE[0]}" || return
    unset -f _configs_bootstrap
else
    source "$HOME/configs/init.sh" || return
fi

##- Variables and MISC Settings
#set this to prevent percent sign showing due to partial line
#ref: https://unix.stackexchange.com/questions/167582/why-zsh-ends-a-line-with-a-highlighted-percent-symbol/167600#167600
PROMPT_EOL_MARK=''


##- import .bashrc
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi
fi

##- Launch Zsh on bash startup

# Show directory listing on login (skipped on WSL)
if [ -f "${HOME}/.zshrc" ] && [[ "$OS_TYPE" != "wsl" ]]; then
    eza --grid --sort=ext --group-directories-first --icons --color-scale;
fi

# Hand off to zsh for interactive shells.
# Mac uses bash as the default login shell post-Catalina, so this ensures
# we still land in zsh without fully replacing bash in the login chain.
if [[ $- == *i* ]] && command -v zsh &>/dev/null; then
    export SHELL=zsh
    exec zsh -l
fi
