# Evaluate with a pinned Home Manager source; this never activates a profile.
{ flake, homeManager }:
let
  pkgs = import flake.inputs.nixpkgs { system = "aarch64-linux"; };
  inherit (pkgs) lib;
  hm = import (homeManager + "/lib") { inherit lib; };
  configuration = settings: hm.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      flake.homeManagerModules.default
      {
        home.username = "chatgpt-prototype-test";
        home.homeDirectory = "/home/chatgpt-prototype-test";
        home.stateVersion = "26.05";
        programs.chatgpt = settings;
      }
    ];
  };
  real = (configuration { enable = true; }).config;
  baseline = (hm.homeManagerConfiguration {
    inherit pkgs;
    modules = [ {
      home.username = "chatgpt-prototype-test";
      home.homeDirectory = "/home/chatgpt-prototype-test";
      home.stateVersion = "26.05";
    } ];
  }).config;
  disabled = (configuration { enable = false; }).config;
  stub = pkgs.writeShellScriptBin "chatgpt" ''
    printf 'CODEX_HOME=%s\n' "$CODEX_HOME"
    printf 'ARG=%s\n' "$@"
  '';
  custom = (configuration {
    enable = true;
    package = stub;
    codexHome = "/tmp/chatgpt profile ' test";
    userDataDir = "/tmp/chatgpt browser ' test";
    registerLoginHandler = false;
  }).config;
  findPackage = name: config: lib.findFirst (package: package.name == name)
    (throw "Missing package ${name}") config.home.packages;
  launcher = findPackage "chatgpt" real;
  desktop = findPackage "chatgpt.desktop" real;
  testLauncher = findPackage "chatgpt" custom;
in
assert builtins.all (item: item.assertion) real.assertions;
assert builtins.all (item: item.assertion) custom.assertions;
assert !(disabled.xdg.mimeApps.enable);
assert !(custom.xdg.mimeApps.enable);
assert map toString disabled.home.packages == map toString baseline.home.packages;
pkgs.runCommand "chatgpt-home-manager-check" { } ''
  mkdir -p "$out/bin" "$out/share/applications" "$out/config"
  cp ${launcher}/bin/chatgpt "$out/bin/chatgpt"
  cp ${desktop}/share/applications/chatgpt.desktop "$out/share/applications/"
  cp ${real.xdg.configFile."mimeapps.list".source} "$out/config/mimeapps.list"
  ${testLauncher}/bin/chatgpt 'codex://prototype-check?value=a b' --another-arg > actual
  cat > expected <<'EOF'
CODEX_HOME=/tmp/chatgpt profile ' test
ARG=--ozone-platform=x11
ARG=--user-data-dir=/tmp/chatgpt browser ' test
ARG=codex://prototype-check?value=a b
ARG=--another-arg
EOF
  diff -u expected actual
  XDG_SESSION_TYPE=wayland ${testLauncher}/bin/chatgpt 'codex://prototype-check?value=a b' --another-arg > wayland-actual
  sed 's/ARG=--ozone-platform=x11/ARG=--ozone-platform=wayland/' expected > wayland-expected
  diff -u wayland-expected wayland-actual
  XDG_SESSION_TYPE=x11 WAYLAND_DISPLAY=wayland-fixture ${testLauncher}/bin/chatgpt 'codex://prototype-check?value=a b' --another-arg > x11-actual
  diff -u expected x11-actual
  XDG_SESSION_TYPE= WAYLAND_DISPLAY=wayland-fixture ${testLauncher}/bin/chatgpt 'codex://prototype-check?value=a b' --another-arg > fallback-actual
  diff -u wayland-expected fallback-actual
  XDG_SESSION_TYPE=wayland ${testLauncher}/bin/chatgpt --ozone-platform=x11 'codex://prototype-check?value=a b' --another-arg > override-actual
  cat > override-expected <<'EOF'
CODEX_HOME=/tmp/chatgpt profile ' test
ARG=--user-data-dir=/tmp/chatgpt browser ' test
ARG=--ozone-platform=x11
ARG=codex://prototype-check?value=a b
ARG=--another-arg
EOF
  diff -u override-expected override-actual
  ${pkgs.desktop-file-utils}/bin/desktop-file-validate "$out/share/applications/chatgpt.desktop"
  ${pkgs.gnugrep}/bin/grep -Fx 'x-scheme-handler/codex=chatgpt.desktop' "$out/config/mimeapps.list"
  ! ${pkgs.gnugrep}/bin/grep -E 'x-scheme-handler/https?=' "$out/config/mimeapps.list"
  cp actual "$out/argument-check.txt"
  cp wayland-actual "$out/wayland-argument-check.txt"
''
