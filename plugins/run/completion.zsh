##- zsh completion for `run` / `runjs`
##- Completes the first argument with `--list` plus the project's npm scripts,
##- just recipes, and make targets; falls back to file completion later.
##- Relies on the helper functions defined in run.sh (sourced before this file).

# compdef needs the completion system initialized; do it if nobody else has.
if ! (( $+functions[compdef] )); then
    autoload -Uz compinit && compinit -C
fi

_run_completion() {
    local root cands
    root=$(_run_find_root) || return 0

    # Only the first arg is a script/recipe/target; the rest are command args.
    if (( CURRENT > 2 )); then
        _files
        return 0
    fi

    # `runjs` only knows about JS scripts; `run` knows all three kinds.
    if [ "${words[1]}" = "runjs" ]; then
        cands=$( { printf '%s\n' '--list'; _run_js_scripts "$root"; } | grep -v '^[[:space:]]*$' )
    else
        cands=$( { printf '%s\n' '--list'; _run_js_scripts "$root"; _run_just_recipes "$root"; _run_make_targets "$root"; } | grep -v '^[[:space:]]*$' )
    fi

    local -a list
    list=("${(@f)cands}")
    compadd -a list
}

compdef _run_completion run runjs
