##- GIT related
# lazy git add commit push all in one
# Automatically sets upstream if branch has never been pushed to remote before
function gitall() {
    local message="${1:-}"
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)

    git add -A
    git commit --allow-empty-message -m "$message"
    # --set-upstream is idempotent: works on new branches and existing ones alike
    git push --set-upstream origin "$branch"
}

function gitreset() {
    git fetch origin
    git reset --hard origin/$(git symbolic-ref --short HEAD)
}

# git submodule add
alias gsub='git submodule add'

alias git-uncommit='git reset --soft HEAD^'
