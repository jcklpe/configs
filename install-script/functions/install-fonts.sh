#!/bin/bash
##- Install fonts from ~/configs/fonts/ to the system font directory
##- NixOS: fonts are managed via configuration.nix, this script is skipped

source "${CONFIGS}/install-script/functions/detect-os.sh"

# NixOS manages fonts declaratively via configuration.nix
if [ "${OS_TYPE}" = "nixos" ]; then
    echo "✓ NixOS: fonts managed via configuration.nix, skipping"
    return 0 2>/dev/null || exit 0
fi

if [ "${OS_TYPE}" = "mac" ]; then
    FONT_DIR="${HOME}/Library/Fonts"
else
    FONT_DIR="${HOME}/.local/share/fonts"
fi

if [ ! -d "${FONT_DIR}" ]; then
    mkdir -p "${FONT_DIR}"
    echo "✓ Created font directory: ${FONT_DIR}"
fi

echo "Installing fonts..."
INSTALLED=0
for font in "${CONFIGS}/fonts/"*.{otf,ttf}; do
    [ -f "$font" ] || continue
    fname=$(basename "$font")
    if [ ! -f "${FONT_DIR}/${fname}" ]; then
        cp "$font" "${FONT_DIR}/"
        echo "  ✓ Installed: ${fname}"
        INSTALLED=$((INSTALLED + 1))
    else
        echo "  ✓ Already installed: ${fname}"
    fi
done

# Refresh font cache on Linux so apps can see newly installed fonts
if [ "${OS_TYPE}" != "mac" ]; then
    fc-cache -f
    echo "✓ Font cache refreshed"
fi

if [ "$INSTALLED" -eq 0 ]; then
    echo "✓ All fonts already installed"
fi
