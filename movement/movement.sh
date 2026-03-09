##- Movement

# Colored grep output everywhere
alias grep='grep --color=auto'

##- Directory listing functions
# lk is the primary listing command (named lk not ls to avoid overriding system ls)
# Falls back to plain ls if eza is not installed, so go() and other callers always work
function lk() {
    if command -v eza &>/dev/null; then
        command eza --grid --sort=ext --group-directories-first --icons --color-scale "$@"
    else
        command ls -F --color=auto "$@"
    fi
}

# go: cd into a directory and list its contents
function go() {
    builtin cd "$@" && lk
}

# up: go up one directory
function up() {
    builtin cd .. && lk
}

# ll: detailed long view — overridden by eza version below if eza is available
function ll() {
    command ls -AlF --color=auto "$@"
}

##- eza-specific commands (only defined when eza is available)
if command -v eza &>/dev/null; then

    # ll: detailed long view with git status (standard alias, easy to remember)
    function ll() {
        eza --long --header --git --color-scale -a "$@"
    }

    # ls-hidden: grid view including hidden dotfiles
    function ls-hidden() {
        command eza --grid --sort=ext --group-directories-first --icons --color-scale -a "$@"
    }

fi

# ls-tree: directory tree view. Pass depth as first arg (default: 2)
# e.g. ls-tree        → 2 levels deep
#      ls-tree 3      → 3 levels deep
#      ls-tree 2 ~/some/folder
function ls-tree() {
    if command -v eza &>/dev/null; then
        command eza --tree --icons --color-scale --level="${1:-2}" "${@:2}"
    else
        command find "${2:-.}" -maxdepth "${1:-2}" | sed 's|[^/]*/|  |g'
    fi
}
