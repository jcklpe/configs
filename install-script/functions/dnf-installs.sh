#!/bin/bash
##- Install GUI apps via dnf on Fedora
##- Only runs on Fedora (OS_TYPE=fedora)

source "${CONFIGS}/install-script/functions/detect-os.sh"

if [ "${OS_TYPE}" != "fedora" ]; then
    return 0 2>/dev/null || exit 0
fi

dnf_install_if_needed() {
    if rpm -q "$1" &>/dev/null; then
        echo_skip "✓ $1 already installed, skipping"
    else
        echo "Installing $1..."
        sudo dnf install -y "$1"
    fi
}

##- Flatpak + Flathub (required for Typora and Extension Manager)
dnf_install_if_needed flatpak
if ! flatpak remotes 2>/dev/null | grep -q flathub; then
    echo "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
else
    echo_skip "✓ Flathub remote already configured, skipping"
fi

##- CLI tools available in default Fedora repos (install before brew runs)
dnf_install_if_needed gcc
dnf_install_if_needed gcc-c++
dnf_install_if_needed make
dnf_install_if_needed zsh
dnf_install_if_needed mc
dnf_install_if_needed ranger
dnf_install_if_needed micro
dnf_install_if_needed trash-cli

##- WezTerm (official RPM from GitHub releases)
if ! rpm -q wezterm &>/dev/null; then
    echo "Installing WezTerm..."
    ARCH=$(uname -m)  # x86_64 or aarch64
    WEZTERM_URL=$(curl -s --fail https://api.github.com/repos/wez/wezterm/releases/latest \
        | grep "browser_download_url" \
        | grep "\.rpm" \
        | grep "${ARCH}" \
        | head -1 \
        | sed 's/.*"\(https[^"]*\)".*/\1/')
    if [ -z "${WEZTERM_URL}" ]; then
        echo_warning "⚠ Could not resolve WezTerm RPM download URL - skipping"
    else
        curl -L "${WEZTERM_URL}" -o /tmp/wezterm.rpm
        sudo dnf install -y /tmp/wezterm.rpm
        rm -f /tmp/wezterm.rpm
    fi
else
    echo_skip "✓ wezterm already installed, skipping"
fi

##- Tabby (official RPM from GitHub releases)
if ! rpm -q tabby &>/dev/null; then
    echo "Installing Tabby..."
    ARCH=$(uname -m)  # x86_64 or aarch64
    TABBY_URL=$(curl -s --fail https://api.github.com/repos/Eugeny/tabby/releases/latest \
        | grep "browser_download_url" \
        | grep "\.rpm" \
        | grep "${ARCH}" \
        | head -1 \
        | sed 's/.*"\(https[^"]*\)".*/\1/')
    if [ -z "${TABBY_URL}" ]; then
        echo_warning "⚠ Could not resolve Tabby RPM download URL - skipping"
    else
        curl -L "${TABBY_URL}" -o /tmp/tabby.rpm
        sudo dnf install -y /tmp/tabby.rpm
        rm -f /tmp/tabby.rpm
    fi
else
    echo_skip "✓ tabby already installed, skipping"
fi

##- VSCode (official Microsoft dnf repo)
if ! rpm -q code &>/dev/null; then
    echo "Enabling VSCode repo and installing..."
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    sudo dnf install -y code
else
    echo_skip "✓ code already installed, skipping"
fi

##- Google Chrome (official Google dnf repo — x86_64 only, not available for ARM64)
if [ "$(uname -m)" = "aarch64" ]; then
    echo_warning "⚠ Google Chrome is not available for ARM64 — skipping"
elif ! rpm -q google-chrome-stable &>/dev/null; then
    echo "Enabling Google Chrome repo and installing..."
    sudo rpm --import https://dl.google.com/linux/linux_signing_key.pub
    sudo sh -c 'echo -e "[google-chrome]\nname=Google Chrome\nbaseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=https://dl.google.com/linux/linux_signing_key.pub" > /etc/yum.repos.d/google-chrome.repo'
    sudo dnf install -y google-chrome-stable
else
    echo_skip "✓ google-chrome already installed, skipping"
fi

##- RPMFusion repos (required for VLC and other non-free packages)
if ! dnf repolist | grep -q rpmfusion-free; then
    echo "Enabling RPMFusion repos..."
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
else
    echo_skip "✓ RPMFusion already enabled, skipping"
fi

##- VLC (via RPMFusion)
dnf_install_if_needed vlc

##- Typora (no official Fedora repo — installed via flatpak)
##- Flatpak is enabled in linux-install.sh beforehand
if ! flatpak list 2>/dev/null | grep -q io.typora.Typora; then
    echo "Installing Typora via flatpak..."
    flatpak install -y flathub io.typora.Typora
else
    echo_skip "✓ Typora (flatpak) already installed, skipping"
fi

##- Gaming (Steam + Proton via RPMFusion — already enabled above)
##- Nvidia: uncomment akmod-nvidia if using an Nvidia GPU
# dnf_install_if_needed akmod-nvidia
dnf_install_if_needed steam

##- GNOME Extension Manager by Matt Jakeman (via flatpak)
if ! flatpak list 2>/dev/null | grep -q com.mattjakeman.ExtensionManager; then
    echo "Installing GNOME Extension Manager via flatpak..."
    flatpak install -y flathub com.mattjakeman.ExtensionManager
else
    echo_skip "✓ Extension Manager (flatpak) already installed, skipping"
fi

##- GNOME Extensions (installed as packages, must be ENABLED via Extension Manager after login)
dnf_install_if_needed gnome-shell-extension-dash-to-panel
##- gnome-vitals: not in default Fedora repos, install via Extension Manager (UUID: 1460)
echo_warning "⚠ gnome-vitals: install manually via Extension Manager (extensions.gnome.org/extension/1460)"
