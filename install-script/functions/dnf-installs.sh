#!/bin/bash
##- Install GUI apps via dnf on Fedora
##- Only runs on Fedora (OS_TYPE=fedora)

source "${CONFIGS}/install-script/functions/detect-os.sh"

if [ "${OS_TYPE}" != "fedora" ]; then
    return 0 2>/dev/null || exit 0
fi

dnf_install_if_needed() {
    if rpm -q "$1" &>/dev/null; then
        echo "✓ $1 already installed, skipping"
    else
        echo "Installing $1..."
        sudo dnf install -y "$1"
    fi
}

##- WezTerm (official COPR repo)
if ! sudo dnf copr list --enabled 2>/dev/null | grep -q "wezfurlong/wezterm"; then
    echo "Enabling wezterm COPR repo..."
    sudo dnf copr enable -y wezfurlong/wezterm
fi
dnf_install_if_needed wezterm

##- Tabby (official RPM from GitHub releases)
if ! rpm -q tabby &>/dev/null; then
    echo "Installing Tabby..."
    TABBY_VERSION=$(curl -s https://api.github.com/repos/Eugeny/tabby/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    curl -L "https://github.com/Eugeny/tabby/releases/latest/download/tabby-${TABBY_VERSION}-linux-x64.rpm" -o /tmp/tabby.rpm
    sudo dnf install -y /tmp/tabby.rpm
    rm /tmp/tabby.rpm
else
    echo "✓ tabby already installed, skipping"
fi

##- VSCode (official Microsoft dnf repo)
if ! rpm -q code &>/dev/null; then
    echo "Enabling VSCode repo and installing..."
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    sudo dnf install -y code
else
    echo "✓ code already installed, skipping"
fi
