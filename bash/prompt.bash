##- 𝗕𝗔𝗦𝗛 𝗣𝗥𝗢𝗠𝗣𝗧

# Add git branch to prompt via PROMPT_COMMAND
PROMPT_COMMAND='
    git_branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$git_branch" ]; then
        PS1="\[\e[36m\]┌─[sh]\[\e[0m\] \[\e[44;30m\] \w \[\e[0m\] \[\e[33m\]($git_branch)\[\e[0m\]\n\[\e[36m\]└─➤\[\e[0m\] "
    else
        PS1="\[\e[36m\]┌─[sh]\[\e[0m\] \[\e[44;30m\] \w \[\e[0m\]\n\[\e[36m\]└─➤\[\e[0m\] "
    fi
'