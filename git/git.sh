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

# Push every branch rewritten by git filter-branch, using the saved original
# remote tip as an exact force-with-lease guard. This is intentionally narrower
# than an unconditional "push every local branch" helper.
function gitpushall() {
    local original_ref
    local remote_ref
    local branch
    local old_oid
    local new_oid
    local source_ref
    local rewritten_count=0

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "gitpushall: not inside a Git repository" >&2
        return 1
    fi

    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "gitpushall: this repository has no origin remote" >&2
        return 1
    fi

    if ! git for-each-ref --format='%(refname)' refs/original/refs/remotes/origin | grep -q .; then
        echo "gitpushall: no filter-branch backup refs found for origin" >&2
        echo "gitpushall: use gitpush for an ordinary current-branch push" >&2
        return 1
    fi

    while IFS= read -r original_ref; do
        remote_ref="${original_ref#refs/original/}"
        branch="${remote_ref#refs/remotes/origin/}"

        [ "$branch" = "HEAD" ] && continue

        old_oid=$(git rev-parse --verify "$original_ref") || return 1
        new_oid=$(git rev-parse --verify "$remote_ref") || return 1

        [ "$old_oid" = "$new_oid" ] && continue

        if git show-ref --verify --quiet "refs/heads/$branch"; then
            source_ref="refs/heads/$branch"
        else
            source_ref="$remote_ref"
        fi

        echo "gitpushall: pushing rewritten branch $branch"
        git push origin \
            "--force-with-lease=refs/heads/${branch}:${old_oid}" \
            "${source_ref}:refs/heads/${branch}" || return 1

        rewritten_count=$((rewritten_count + 1))
    done < <(git for-each-ref --format='%(refname)' refs/original/refs/remotes/origin)

    if [ "$rewritten_count" -eq 0 ]; then
        echo "gitpushall: no rewritten origin branches need pushing"
        return 0
    fi

    echo "gitpushall: pushed $rewritten_count rewritten branch(es)"
    echo "gitpushall: verify the remote purge before deleting refs/original"
}

function gitreset() {
    git fetch origin
    git reset --hard origin/$(git symbolic-ref --short HEAD)
}

# git submodule add
alias gsub='git submodule add'

alias git-uncommit='git reset --soft HEAD^'
