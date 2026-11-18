# Linux GNOME drop-down setup
The Linux config matches the Mac's 12px inner border radius and top docking (`dockFill: 0.96`). Outer window rounding still depends on the compositor. Keep the platform-specific files separate: Linux uses Ctrl-Shift-C/V while macOS uses Command-C/V.

## Wayland toggle
The native Ctrl-Space binding is not a reliable GNOME Wayland global shortcut with the tested Tabby/Electron version. Quake Anything owns the compositor-level show/hide shortcut instead. The tested configuration uses `tabby.desktop`, top docking, `<Control>space`, and 50% monitor height. The extension's size is not the same setting as Tabby's dock fill.

Install Quake Anything from its [official GNOME marketplace page](https://extensions.gnome.org/extension/10596/quake-anything/). Version 1.1.0 (marketplace version 5) supports GNOME 46–51. Configure only the Tabby entry. Newly installed extensions may require logging out/in on Wayland; save work first. Let the shortcut launch Tabby before opening it manually because the extension manages windows it spawns and Tabby is single-instance. Do not kill terminals to activate this setup.

For declarative installation, see [the optional Home Manager module](../nixos/README.md).

## Taskbar exclusion
Quake Anything minimizes its window when hiding it. Dash to Panel therefore keeps an ordinary taskbar entry. `patch-dash-to-panel.py` deliberately excludes only the `tabby.desktop` app from the panel at all times; it does not change other applications, GNOME overview, or Quake's shortcut.

The patch targets Dash to Panel's `getAppInfos()` return hook, was checked against version 74, is idempotent, and refuses an unexpected source layout. Back up the installed `taskbar.js` before manually applying it. Extension updates may replace local edits. The Home Manager module applies it during the package build instead. Restore the original file to undo a manual patch. A fresh login is the reliable way to load changed extension modules; do not restart GNOME Shell inside a running Wayland session.

## Validation and limits
- YAML parsing and active config symlink were checked on Fedora GNOME Wayland.
- Quake Anything was observed ACTIVE with the dedicated Tabby entry.
- The taskbar filter has unit tests and was checked against the installed source; its visible effect after a fresh login still needs human verification.
- Visual corner clipping and focused/unfocused shortcut behavior require desktop testing. Do not infer a successful toggle from installed files alone.
- A `GlobalShortcutsPortal` launcher experiment did not resolve the native shortcut on the tested runtime. It is not required by the Quake integration and is not reproduced by the Nix module.
- Home Manager evaluation/build and NixOS activation have not been run. This does not convert the current Fedora system.

Run the portable patch tests with `PYTHONDONTWRITEBYTECODE=1 python3 tabby/test_taskbar_patch.py`.
