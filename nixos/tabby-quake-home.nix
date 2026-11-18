# Import into Home Manager, not directly into a NixOS system module.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.tabby-quake;
  quakeAnything = pkgs.callPackage ./quake-anything.nix { };
  dashToPanel = if cfg.hideFromTaskbar then
    pkgs.gnomeExtensions.dash-to-panel.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        ${pkgs.python3}/bin/python ${../tabby/patch-dash-to-panel.py} \
          "$out/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com/taskbar.js"
      '';
    })
  else pkgs.gnomeExtensions.dash-to-panel;
  supportedShells = [ "46" "47" "48" "49" "50" "51" ];
in
{
  options.programs.tabby-quake = {
    enable = lib.mkEnableOption "Tabby drop-down control through GNOME Quake Anything";
    hideFromTaskbar = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply the narrowly scoped Dash to Panel patch excluding tabby.desktop.";
    };
    sizePercent = lib.mkOption {
      type = lib.types.ints.between 10 90;
      default = 50;
      description = "Quake Anything's fraction of the monitor work area, not Tabby's dockFill.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [ {
      assertion = builtins.elem (lib.versions.major pkgs.gnome-shell.version) supportedShells;
      message = "Pinned Quake Anything 1.1.0 supports GNOME Shell 46–51; review the pin before enabling on another version.";
    } ];

    home.packages = [ pkgs.tabby quakeAnything dashToPanel ];
    dconf.enable = true;
    xdg.configFile."tabby/config.yaml".text = builtins.replaceStrings
      [ "  shell: /bin/zsh" ]
      [ "  shell: ${pkgs.zsh}/bin/zsh" ]
      (builtins.readFile ../tabby/config.linux.yaml);

    dconf.settings = {
      "org/gnome/shell".enabled-extensions = [
        quakeAnything.extensionUuid
        "dash-to-panel@jderose9.github.com"
      ];
      "org/gnome/shell/extensions/quake-anything".entries = [
        (lib.hm.gvariant.mkTuple [
          "tabby" "tabby.desktop" "top" "<Control>space"
          (lib.hm.gvariant.mkInt32 cfg.sizePercent)
        ])
      ];
    };
  };
}
