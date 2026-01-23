##- 𝗕𝗔𝗦𝗛 𝗣𝗥𝗢𝗠𝗣𝗧

# set a fancy prompt (non-color, unless we know we "want" color)

force_color_prompt=yes
TERM=xterm-256color
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# check if SSH
if [ -n "$SSH_CLIENT" ]; then
export SSHstatus="\e[30;103m ♆"
else
export SSHstatus="\e[30;103m ⚡";
fi

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
    else
    color_prompt=
    fi
fi



if [ "$color_prompt" = yes ]; then
    PS1="\n ${SSHstatus} \e[30;44m \w \[\033[00m\]\n    \e[96m⭄>> \e[0m \[\033[00m\]";

    # export PS1=$'   \e[0;34m \u2692\e[m\e[0;31m \u26A1  [\w] \e[m\e[0;36m >>>'
else
    PS1='\n \w>>> '
fi
# unset color_prompt force_color_prompt

# not sure what this does