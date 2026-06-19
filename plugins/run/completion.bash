##- bash completion for `run` / `runjs`
##- Completes the first argument with `--list` plus the project's npm scripts,
##- just recipes, and make targets; falls back to file completion later.
##- Relies on the helper functions defined in run.sh (sourced before this file).

_run_complete() {
    local cur root cands
    cur="${COMP_WORDS[COMP_CWORD]}"
    root="$(_run_find_root)" || return 0

    # Only the first arg is a script/recipe/target; the rest are command args.
    if [ "$COMP_CWORD" -gt 1 ]; then
        COMPREPLY=( $(compgen -f -- "$cur") )
        return 0
    fi

    # `runjs` only knows about JS scripts; `run` knows all three kinds.
    if [ "${COMP_WORDS[0]}" = "runjs" ]; then
        cands="$( { printf '%s\n' '--list'; _run_js_scripts "$root"; } | grep -v '^[[:space:]]*$' )"
    else
        cands="$( { printf '%s\n' '--list'; _run_js_scripts "$root"; _run_just_recipes "$root"; _run_make_targets "$root"; } | grep -v '^[[:space:]]*$' )"
    fi

    COMPREPLY=( $(compgen -W "$cands" -- "$cur") )
}

complete -F _run_complete run runjs
