##- Simple prompt for VS Code terminal
##- VS Code's terminal integration doesn't work well with complex prompts like Powerlevel10k

# Enable command substitution in prompt
setopt PROMPT_SUBST

# Use vcs_info for git branch (avoids subshell in RPROMPT which breaks VS Code shell integration)
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '(%b)'
zstyle ':vcs_info:*' enable git

# Check if terminal supports UTF-8
if locale charmap 2>/dev/null | grep -qi utf; then
    # Fancy version with unicode box chars
    PROMPT='%F{cyan}┌─%f %K{blue}%F{black} %~ %k%f %F{yellow}${vcs_info_msg_0_}%f
%F{cyan}└─➤%f '
    # RPROMPT='%F{yellow}${vcs_info_msg_0_}%f'
else
    # Simple fallback
    PROMPT='%K{blue}%F{black} %~ %k%f ${vcs_info_msg_0_}
> '
    # RPROMPT='%F{yellow}${vcs_info_msg_0_}%f'
fi
