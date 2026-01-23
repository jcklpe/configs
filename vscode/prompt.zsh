##- Simple prompt for VS Code terminal
##- VS Code's terminal integration doesn't work well with complex prompts like Powerlevel10k

# Enable command substitution in prompt
setopt PROMPT_SUBST

# Check if terminal supports UTF-8
if locale charmap 2>/dev/null | grep -qi utf; then
    # Fancy version with unicode box chars
    PROMPT='%F{cyan}┌─%f %K{blue}%F{black} %~ %k%f
%F{cyan}└─➤%f '
    RPROMPT='%F{yellow}$(git branch --show-current 2>/dev/null | sed "s/^/(/;s/$/)/")%f'
else
    # Simple fallback
    PROMPT='%K{blue}%F{black} %~ %k%f
> '
    RPROMPT='%F{yellow}$(git branch --show-current 2>/dev/null | sed "s/^/(/;s/$/)/")%f'
fi
