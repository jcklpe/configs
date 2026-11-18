# NixOS desktop configuration
The existing `configuration.nix` is a starting point, not an activated or tested migration of the Fedora host. Keep the installed system's hardware configuration and state version. This change does not run `nixos-rebuild`, install Nix, or convert Fedora.

## Opt-in Tabby quake integration
`tabby-quake-home.nix` is a Home Manager module. Add it to an existing Home Manager configuration; do not import it directly into `configuration.nix`. Home Manager must already be integrated with your chosen NixOS/nixpkgs release. This repository does not choose or pin those releases.

```nix
# In home.nix, with the configs repository available at this relative path:
{
  imports = [ ./configs/nixos/tabby-quake-home.nix ];
  programs.tabby-quake.enable = true;
  programs.tabby-quake.sizePercent = 50;
  programs.tabby-quake.hideFromTaskbar = true;
}
```

The module installs Tabby, the pinned GNOME Marketplace Quake Anything 1.1.0 artifact, and Dash to Panel. It manages the Linux Tabby config and replaces its `/bin/zsh` setting with the Nix store zsh path. It sets Ctrl-Space to toggle only `tabby.desktop`, docked at the top at 50% height. This size is independent of Tabby's `dockFill: 0.96`. The latter and the 12px CSS radius preserve the existing Linux appearance configuration; the compositor still determines actual outer window decoration.

The taskbar exclusion is a narrow build-time patch to Dash to Panel's final application list. It excludes only `tabby.desktop`, always, rather than hiding all minimized apps. The shared patch helper fails on an unexpected upstream source shape rather than silently applying a broad or ineffective patch. Set `hideFromTaskbar = false` to use the unmodified package. The patch may need review when nixpkgs updates Dash to Panel.

### Before activation
- Back up or deliberately retire an existing `~/.config/tabby/config.yaml` symlink before Home Manager takes ownership. Do not run the dotfiles symlink installer against the same managed target afterward. Home Manager may correctly refuse an existing conflicting file.
- Remove duplicate unmodified Dash to Panel packages from the system package list when enabling this module. In particular, the existing `configuration.nix` lists `gnomeExtensions.dash-to-panel`; use the module's package instead. Retire the manually installed user extension with the same UUID before relying on the packaged variant, because the user-local copy can shadow it. Keep a recoverable copy until verified.
- Declare any additional desired GNOME extension UUIDs in Home Manager's `dconf.settings."org/gnome/shell".enabled-extensions`. Nix list definitions merge, but unmanaged live dconf additions are not automatically preserved by declarative activation. This module enables Quake Anything and Dash to Panel only.
- Do not reuse the failed Fedora portal launcher override as the fix: Quake Anything owns the shortcut at the compositor level. If moving an existing home directory, review `~/.local/share/applications/tabby.desktop` so it does not shadow the Nix launcher with a stale `/opt/Tabby` command.
- Save terminal work before logging out. GNOME on Wayland may require logout/login to discover newly installed extensions. Let Ctrl-Space launch Tabby before manually opening it, because Quake Anything manages windows it creates and Tabby is single-instance.

## Verification and limitations
The marketplace archive's SHA-256 was calculated from the downloaded artifact and pinned in `quake-anything.nix`. Its metadata declares GNOME 46–51 support; the module checks that range. The extension schema uses `a(ssssi)` entries and the Home Manager declaration explicitly uses an int32 for the size field.

Nix is not installed on the Fedora host used to prepare these files. Nix evaluation, builds, Home Manager activation, NixOS rebuilding, and runtime behavior of the packaged extensions have **not** been tested. Run `home-manager build` with your real pinned configuration before activation; resolve package/version or fail-fast patch errors instead of bypassing them. After activation/login verify Ctrl-Space show/hide, the intended Tabby size, other applications' taskbar icons, and Tabby's taskbar exclusion. No visual taskbar verification is claimed for the local Fedora patch either.

## Rollback
Disable the Home Manager option and activate your previous known-good generation to roll back managed settings and packages. Restore the prior Tabby config ownership and any manually retired extension only when needed. Do not delete active terminal sessions to test rollback. Setting `hideFromTaskbar = false` only removes the exclusion patch; it leaves the Quake toggle enabled.
