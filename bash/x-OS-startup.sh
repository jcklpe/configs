##- CROSS-𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
# settings/variables
# variables
OSis=$(uname -a);
    ##- Windows Subystem Layer
    if [[ $OSis == *"Microsoft"* ]]; then
        if [ -d "./home" ]; then
            cd home;
        else
            exa --grid --sort=ext --group-directories-first --icons --color-scale;
        fi
    fi
