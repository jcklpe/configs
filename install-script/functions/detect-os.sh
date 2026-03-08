#!/usr/bin/env bash
##- OS detection module
##- Sets and exports OS_TYPE: mac | nixos | wsl | linux | unknown
##- Source this file wherever OS_TYPE is needed (init.sh, install scripts, etc.)

case "$(uname -s)" in
    Darwin*)
        export OS_TYPE="mac"
        ;;

    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            export OS_TYPE="wsl"
        elif [ -f /etc/NIXOS ]; then
            export OS_TYPE="nixos"
        else
            export OS_TYPE="linux"
        fi
        ;;

    *)
        export OS_TYPE="unknown"
        ;;
esac
