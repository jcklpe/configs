# Pinned reviewed GNOME Extensions artifact, not a moving Git checkout.
{ lib, stdenvNoCC, fetchurl, unzip, glib }:

stdenvNoCC.mkDerivation {
  pname = "gnome-shell-extension-quake-anything";
  version = "1.1.0";

  src = fetchurl {
    url = "https://extensions.gnome.org/download-extension/quake-anything@yccoskun.github.io.shell-extension.zip?version_tag=78360";
    hash = "sha256-bqnYl3Emy6SJScUvHlFX0ZV19y+KSiVcrf+JARFeTnM=";
  };

  nativeBuildInputs = [ unzip glib ];
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    extensionDir="$out/share/gnome-shell/extensions/quake-anything@yccoskun.github.io"
    mkdir -p "$extensionDir"
    unzip -q "$src" -d "$extensionDir"
    glib-compile-schemas --strict "$extensionDir/schemas"
    runHook postInstall
  '';

  passthru.extensionUuid = "quake-anything@yccoskun.github.io";
  meta = {
    description = "GNOME Shell drop-down windows for arbitrary applications";
    homepage = "https://extensions.gnome.org/extension/10596/quake-anything/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
