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

##- CLI tools available in default Fedora repos (install before brew runs)
DNF_CLI_TOOLS=(gcc gcc-c++ make zsh mc ranger)
for pkg in "${DNF_CLI_TOOLS[@]}"; do
    dnf_install_if_needed "$pkg"
done

##- WezTerm (official RPM from GitHub releases)
if ! rpm -q wezterm &>/dev/null; then
    echo "Installing WezTerm..."
    ARCH=$(uname -m)  # x86_64 or aarch64
    WEZTERM_URL=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest \
        | grep "browser_download_url" \
        | grep "\.rpm" \
        | grep "${ARCH}" \
        | head -1 \
        | sed 's/.*"\(https[^"]*\)".*/\1/')
    if [ -z "${WEZTERM_URL}" ]; then
        echo "✗ Could not resolve WezTerm RPM download URL - skipping"
    else
        curl -L "${WEZTERM_URL}" -o /tmp/wezterm.rpm
        sudo dnf install -y /tmp/wezterm.rpm
        rm -f /tmp/wezterm.rpm
    fi
else
    echo "✓ wezterm already installed, skipping"
fi

##- Tabby (official RPM from GitHub releases)
if ! rpm -q tabby &>/dev/null; then
    echo "Installing Tabby..."
    ARCH=$(uname -m)  # x86_64 or aarch64
    TABBY_URL=$(curl -s https://api.github.com/repos/Eugeny/tabby/releases/latest \
        | grep "browser_download_url" \
        | grep "\.rpm" \
        | grep "${ARCH}" \
        | head -1 \
        | sed 's/.*"\(https[^"]*\)".*/\1/')
    if [ -z "${TABBY_URL}" ]; then
        echo "✗ Could not resolve Tabby RPM download URL - skipping"
    else
        curl -L "${TABBY_URL}" -o /tmp/tabby.rpm
        sudo dnf install -y /tmp/tabby.rpm
        rm -f /tmp/tabby.rpm
    fi
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
