##- GIT related
# gitall and gitcommit both `git add -A` and then commit whatever is staged.
# That sweeps up everything in the working tree, including files an agent is
# midway through writing. Do not run either while an agent is working in the
# repo. See docs/decisions/0003-agent-commit-policy.md. gitpush is always safe.

# lazy git add commit push all in one
# Automatically sets upstream if branch has never been pushed to remote before
function gitall() {
    local message="$*"
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)

    git add -A
    git commit --allow-empty-message -m "$message"
    # --set-upstream is idempotent: works on new branches and existing ones alike
    git push --set-upstream origin "$branch"
}

# lazy git add + commit, no push. For stray local work not worth an agent's time.
function gitcommit() {
    local message="$*"
    if [ -z "$message" ]; then
        echo "gitcommit: need a commit message" >&2
        return 1
    fi

    git add -A
    git commit -m "$message"
}

# push the current branch, staging and committing nothing
function gitpush() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$branch" ]; then
        echo "gitpush: not on a branch (detached HEAD?)" >&2
        return 1
    fi

    # --set-upstream is idempotent, and keeps `git status` ahead/behind working
    git push --set-upstream origin "$branch"
}

function gitreset() {
    git fetch origin
    git reset --hard origin/$(git symbolic-ref --short HEAD)
}

# git submodule add
alias gsub='git submodule add'

alias git-uncommit='git reset --soft HEAD^'
