##- run: smart dev-script / env-command dispatcher
##- Walks up from $PWD to the nearest project root, detects the toolchain
##- (JS package manager, Python env, make/just), then runs your command with
##- the right prefix. So instead of:
##-     corepack pnpm run start:frontend      ->  run start:frontend
##-     poetry run python manage.py migrate   ->  run python manage.py migrate
##- With no args or `--list` it lists what's runnable in the current project.
##-
##- Cross-shell: must work in BOTH bash (3.2 on mac) and zsh. So: no bash 4+
##- features (associative arrays, ${var,,}), and never rely on word-splitting an
##- unquoted variable (zsh doesn't split by default) — pass prefix words literally.

# Walk up from $PWD to the nearest directory holding a known project marker.
_run_find_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -e "$dir/package.json" ] || [ -e "$dir/pyproject.toml" ] || \
           [ -e "$dir/Pipfile" ] || [ -e "$dir/pixi.toml" ] || \
           [ -e "$dir/Makefile" ] || [ -e "$dir/GNUmakefile" ] || \
           [ -e "$dir/justfile" ] || [ -e "$dir/Justfile" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Echo the resolved command (dimmed) to stderr, then run it.
_run_exec() {
    printf '\033[2m-> %s\033[0m\n' "$*" >&2
    "$@"
}

# Print the JS package manager for a root (pnpm|yarn|bun|npm), or nothing.
# The packageManager field (corepack's canonical signal) wins over lockfiles.
_run_js_pm() {
    local root="$1" field=""
    [ -f "$root/package.json" ] || return 1
    if command -v node >/dev/null 2>&1; then
        field=$(node -e 'try{process.stdout.write((require(process.argv[1]).packageManager||"").split("@")[0])}catch(e){}' "$root/package.json" 2>/dev/null)
    fi
    if [ -n "$field" ]; then printf '%s\n' "$field"; return 0; fi
    if   [ -f "$root/pnpm-lock.yaml" ];   then printf 'pnpm\n'
    elif [ -f "$root/yarn.lock" ];        then printf 'yarn\n'
    elif [ -f "$root/bun.lockb" ] || [ -f "$root/bun.lock" ]; then printf 'bun\n'
    else printf 'npm\n'
    fi
}

# Run a package-manager invocation, prefixing corepack when it makes sense.
# Args are passed literally (no string-splitting), so this is zsh-safe.
_run_js() {
    local pm="$1"; shift
    case "$pm" in
        pnpm|yarn)
            if command -v corepack >/dev/null 2>&1; then
                _run_exec corepack "$pm" "$@"; return $?
            fi ;;
    esac
    _run_exec "$pm" "$@"
}

# Print the Python env tool (poetry|uv|pixi|pipenv) for a root, or nothing.
# All four use the `<tool> run <cmd>` form.
_run_py_tool() {
    local root="$1" py="$root/pyproject.toml"
    if { [ -f "$root/poetry.lock" ] || grep -q '^\[tool\.poetry\]' "$py" 2>/dev/null; } && command -v poetry >/dev/null 2>&1; then printf 'poetry\n'; return 0; fi
    if { [ -f "$root/uv.lock" ]     || grep -q '^\[tool\.uv\]'     "$py" 2>/dev/null; } && command -v uv     >/dev/null 2>&1; then printf 'uv\n';     return 0; fi
    if { [ -f "$root/pixi.toml" ]   || grep -q '^\[tool\.pixi\]'   "$py" 2>/dev/null; } && command -v pixi   >/dev/null 2>&1; then printf 'pixi\n';   return 0; fi
    if [ -f "$root/Pipfile" ] && command -v pipenv >/dev/null 2>&1; then printf 'pipenv\n'; return 0; fi
    return 1
}

# Print package.json script names, one per line. node -> jq -> python3 -> grep.
_run_js_scripts() {
    local root="$1"
    [ -f "$root/package.json" ] || return 0
    if command -v node >/dev/null 2>&1; then
        node -e 'try{var s=require(process.argv[1]).scripts||{};console.log(Object.keys(s).join("\n"))}catch(e){}' "$root/package.json" 2>/dev/null
    elif command -v jq >/dev/null 2>&1; then
        jq -r '.scripts // {} | keys[]' "$root/package.json" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys;print("\n".join(json.load(open(sys.argv[1])).get("scripts",{})))' "$root/package.json" 2>/dev/null
    fi
}

# Print make target names, one per line (best-effort scan).
_run_make_targets() {
    local root="$1" f mf=""
    for f in Makefile GNUmakefile makefile; do
        [ -f "$root/$f" ] && { mf="$root/$f"; break; }
    done
    [ -n "$mf" ] || return 0
    grep -E '^[a-zA-Z0-9][a-zA-Z0-9_.-]*:' "$mf" 2>/dev/null | sed 's/:.*//' | sort -u
}

# Print justfile recipe names, one per line.
_run_just_recipes() {
    local root="$1"
    { [ -f "$root/justfile" ] || [ -f "$root/Justfile" ]; } || return 0
    command -v just >/dev/null 2>&1 || return 0
    ( builtin cd "$root" && just --summary 2>/dev/null | tr ' ' '\n' )
}

# True if $1 equals one of the newline-separated entries read from stdin.
_run_in_list() {
    local needle="$1" line
    while IFS= read -r line; do
        [ -n "$line" ] && [ "$line" = "$needle" ] && return 0
    done
    return 1
}

# Print what `run` can discover in the current project.
_run_print_list() {
    local root="$1" pm="$2" js_scripts="$3" just_recipes="$4" make_targets="$5" py_tool="$6"
    printf 'project: %s\n' "$root"
    [ -n "$pm" ]      && printf '  js package manager: %s\n' "$pm"
    [ -n "$py_tool" ] && printf '  python env: %s run\n' "$py_tool"
    if [ -n "$js_scripts" ]; then
        printf '\nnpm scripts:\n';  printf '%s\n' "$js_scripts"   | sed 's/^/  run /'
    fi
    if [ -n "$just_recipes" ]; then
        printf '\njust recipes:\n'; printf '%s\n' "$just_recipes" | sed 's/^/  run /'
    fi
    if [ -n "$make_targets" ]; then
        printf '\nmake targets:\n'; printf '%s\n' "$make_targets" | sed 's/^/  run /'
    fi
    [ -z "${js_scripts}${just_recipes}${make_targets}" ] && \
        printf '\n(no named scripts found - "run <cmd>" runs <cmd> inside the project env)\n'
}

# Print what `runjs` can discover in the current project.
_runjs_print_list() {
    local root="$1" pm="$2" js_scripts="$3"
    printf 'project: %s\n  js package manager: %s\n' "$root" "$pm"
    [ -n "$js_scripts" ] && { printf '\nnpm scripts:\n'; printf '%s\n' "$js_scripts" | sed 's/^/  runjs /'; }
}

run() {
    local root
    root=$(_run_find_root) || {
        printf 'run: no project found (package.json, pyproject.toml, Makefile, justfile, ...) from %s upward\n' "$PWD" >&2
        return 1
    }

    local pm js_scripts make_targets just_recipes py_tool
    pm=$(_run_js_pm "$root")
    js_scripts=$(_run_js_scripts "$root")
    make_targets=$(_run_make_targets "$root")
    just_recipes=$(_run_just_recipes "$root")
    py_tool=$(_run_py_tool "$root")

    # No args or --list: show what's runnable here.
    if [ "$#" -eq 0 ]; then
        _run_print_list "$root" "$pm" "$js_scripts" "$just_recipes" "$make_targets" "$py_tool"
        return 0
    fi
    if [ "$1" = "--list" ]; then
        if [ "$#" -ne 1 ]; then
            printf 'run: --list does not take additional arguments\n' >&2
            return 2
        fi
        _run_print_list "$root" "$pm" "$js_scripts" "$just_recipes" "$make_targets" "$py_tool"
        return 0
    fi

    local first="$1"

    # 1. A package.json script.
    if [ -n "$pm" ] && printf '%s\n' "$js_scripts" | _run_in_list "$first"; then
        _run_js "$pm" run "$@"; return $?
    fi
    # 2. A just recipe.
    if printf '%s\n' "$just_recipes" | _run_in_list "$first"; then
        ( builtin cd "$root" && _run_exec just "$@" ); return $?
    fi
    # 3. A make target.
    if printf '%s\n' "$make_targets" | _run_in_list "$first"; then
        _run_exec make -C "$root" "$@"; return $?
    fi
    # 4. Arbitrary command: run inside the project env. Python wins when present
    #    (JS one-off commands are rare; JS work usually goes through scripts).
    if [ -n "$py_tool" ]; then
        _run_exec "$py_tool" run "$@"; return $?
    fi
    if [ -n "$pm" ]; then
        _run_js "$pm" exec "$@"; return $?
    fi
    # 5. Nothing detected for passthrough — just run it.
    _run_exec "$@"
}

# runjs: like `run`, but always uses the JS package manager. Handy in a
# monorepo where both package.json and a Python env live at the same root and
# you want `runjs python-ish-bin` to go through `<pm> exec` instead of poetry.
runjs() {
    local root pm js_scripts
    root=$(_run_find_root) || {
        printf 'runjs: no project found from %s upward\n' "$PWD" >&2
        return 1
    }
    pm=$(_run_js_pm "$root") || {
        printf 'runjs: no package.json found at %s\n' "$root" >&2
        return 1
    }
    js_scripts=$(_run_js_scripts "$root")

    if [ "$#" -eq 0 ]; then
        _runjs_print_list "$root" "$pm" "$js_scripts"
        return 0
    fi
    if [ "$1" = "--list" ]; then
        if [ "$#" -ne 1 ]; then
            printf 'runjs: --list does not take additional arguments\n' >&2
            return 2
        fi
        _runjs_print_list "$root" "$pm" "$js_scripts"
        return 0
    fi

    if printf '%s\n' "$js_scripts" | _run_in_list "$1"; then
        _run_js "$pm" run "$@"
    else
        _run_js "$pm" exec "$@"
    fi
}
