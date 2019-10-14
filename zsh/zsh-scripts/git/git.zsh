##- GIT related
# lazy git add commit push all in one
function gitall() {
    git add .
    git commit -a -m "$1"
    git push origin
}

# git submodule add
alias gsub='git submodule add'

# create a new branch of a git you are currently on
alias git-create='git checkout -b master'

# pull from master branch and discard old changes
alias git-pull-refresh='git stash && git pull'

alias git-uncommit=' git reset --soft HEAD^'