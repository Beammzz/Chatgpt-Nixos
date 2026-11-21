{ pkgs, payload, source, version, runtimeLibraries, meta }:
let
  inherit (pkgs) lib;
  nativePayload = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-payload";
    inherit version;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.python3 ];
    buildInputs = runtimeLibraries ++ [ pkgs.stdenv.cc.cc.lib ];
    dontAutoPatchelf = true;
    dontStrip = true;
    dontPatchELF = true;
    autoPatchelfFlags = [ "--preserve-origin" ];
    # Include libraries loaded with dlopen, without leaking LD_LIBRARY_PATH
    # into local commands (especially the host setuid sudo wrapper).
    appendRunpaths = [ (lib.makeLibraryPath runtimeLibraries) "/run/opengl-driver/lib" ];
    installPhase = ''
      mkdir -p "$out"
      cp -r ${payload}/lib ${payload}/share "$out/"
      chmod -R u+w "$out"
    '';
    postFixup = ''
      mapfile -d "" -t native_elfs < <(
        python ${./select-native-elf.py} "$out/lib/chatgpt" ${pkgs.stdenv.hostPlatform.system}
      )
      test "''${#native_elfs[@]}" -gt 0
      addAutoPatchelfSearchPath "$out/lib/chatgpt"
      autoPatchelf --no-recurse "''${native_elfs[@]}"
    '';
    inherit meta;
  };

  preparePlugins = pkgs.writeShellApplication {
    name = "chatgpt-prepare-native-plugins";
    runtimeInputs = [ pkgs.coreutils pkgs.util-linux ];
    text = ''
      umask 077
      cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/chatgpt-nixos/native-${version}-${source.architecture}-${builtins.baseNameOf nativePayload}"
      mkdir -p "$cache_root"
      exec 9>"$cache_root/.lock"
      flock 9
      if [[ ! -d "$cache_root/resources" ]]; then
        staging_root=$(mktemp -d "$cache_root/.staging.XXXXXXXX")
        trap 'rm -rf "$staging_root"' EXIT
        mkdir -p "$staging_root/resources/plugins"
        cp -r ${nativePayload}/lib/chatgpt/resources/plugins/openai-bundled "$staging_root/resources/plugins/"
        chmod -R u+w "$staging_root/resources"
        mv "$staging_root/resources" "$cache_root/resources"
      fi
      printf '%s\n' "$cache_root/resources"
    '';
  };

  environment = ''
    CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH="$(${preparePlugins}/bin/chatgpt-prepare-native-plugins)" || exit "$?"
    export CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH
    export CHATGPT_RESOURCES=${nativePayload}/lib/chatgpt/resources
    export SSL_CERT_FILE="''${SSL_CERT_FILE:-${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt}"
    export XDG_DATA_DIRS="${nativePayload}/share:${pkgs.gsettings-desktop-schemas}/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    # Keep the caller's tools and /run/wrappers/bin (sudo) ahead of fallbacks.
    export PATH="$PATH:${lib.makeBinPath [ pkgs.bubblewrap pkgs.xdg-utils pkgs.git ]}"
  '';

  launcher = pkgs.writeShellScriptBin "chatgpt" ''
    set -e
    ${environment}
    exec ${nativePayload}/lib/chatgpt/ChatGPT "$@"
  '';
  app = pkgs.symlinkJoin {
    name = "chatgpt-${version}";
    paths = [ launcher ];
    postBuild = ''
      cp -r ${nativePayload}/share "$out/share"
      chmod -R u+w "$out/share"
      substituteInPlace "$out/share/applications/chatgpt.desktop" \
        --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt %U" \
        --replace-fail 'x-scheme-handler/http;x-scheme-handler/https;' ""
    '';
    passthru = { inherit payload nativePayload source; };
    meta = meta // { mainProgram = "chatgpt"; };
  };
  shell = pkgs.writeShellScriptBin "chatgpt-native-shell" ''
    set -e
    ${environment}
    exec ${pkgs.bashInteractive}/bin/bash "$@"
  '';
in {
  inherit app shell nativePayload;
}
