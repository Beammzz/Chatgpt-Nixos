{ pkgs }:
let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  inherit (sources) version;
  source = sources.${pkgs.stdenv.hostPlatform.system}
    or (throw "ChatGPT prototype supports aarch64-linux and x86_64-linux only");

  meta = {
    description = "Official ChatGPT desktop app in a Nix FHS environment (prototype)";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    # The Electron copyright file does not establish the app's license.
    license = lib.licenses.unfree;
    platforms = [ "aarch64-linux" "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  payload = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-payload";
    inherit version;
    src = pkgs.fetchurl { inherit (source) url sha256; };
    nativeBuildInputs = [ pkgs.binutils pkgs.xz ];

    unpackPhase = ''
      runHook preUnpack
      mkdir extracted
      ar p "$src" data.tar.xz | tar -xJf - --no-same-owner --no-same-permissions -C extracted
      runHook postUnpack
    '';
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib"
      cp -r extracted/usr/lib/chatgpt "$out/lib/chatgpt"
      cp -r extracted/usr/share "$out/share"
      runHook postInstall
    '';
    # Retain vendor executables, native-module ABI, resource paths and RPATHs.
    # Foreign-platform prebuilds are not patched or added as runtime libraries.
    dontFixup = true;
    inherit meta;
  };

  # The app copies bundled plugins then rewrites their manifests. Nix store
  # files are 0444/0555; fs.cp preserves those modes and the rewrite fails.
  # Cache identical bytes with user-writable metadata, then expose that source
  # read-only at its canonical resource path inside the FHS mount namespace.
  preparePlugins = pkgs.writeShellApplication {
    name = "chatgpt-prepare-plugins";
    runtimeInputs = [ pkgs.coreutils pkgs.util-linux ];
    text = ''
      cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/chatgpt-nixos/${version}-${source.architecture}-${builtins.substring 0 12 source.sha256}"
      mkdir -p "$cache_root"
      exec 9>"$cache_root/.lock"
      flock 9
      if [[ ! -d "$cache_root/openai-bundled" ]]; then
        staging_root=$(mktemp -d "$cache_root/.staging.XXXXXXXX")
        trap 'rm -rf "$staging_root"' EXIT
        cp -r ${payload}/lib/chatgpt/resources/plugins/openai-bundled "$staging_root/openai-bundled"
        chmod -R u+w "$staging_root/openai-bundled"
        mv "$staging_root/openai-bundled" "$cache_root/openai-bundled"
      fi
      printf '%s\n' "$cache_root/openai-bundled"
    '';
  };

  runtimeLibraries = with pkgs; [
    gtk3 glib at-spi2-core nss nspr dbus
    (lib.getLib cups) expat alsa-lib libgbm libdrm
    libX11 libXext libXcomposite libXdamage libXfixes libXrandr
    libxcb libxkbcommon cairo pango gdk-pixbuf udev
    libnotify libGL vulkan-loader wayland
    openssl libusb1 tpm2-tss libsecret (lib.getLib pulseaudio)
    (lib.getLib qt5.qtbase) (lib.getLib qt6.qtbase)
  ];

  native = import ./native.nix {
    inherit pkgs payload source version runtimeLibraries;
    meta = meta // { description = "Official ChatGPT desktop app with native Nix runtime libraries"; };
  };

  fhs = pkgs.buildFHSEnv {
    pname = "chatgpt";
    inherit version;
    executableName = "chatgpt";
    multiArch = false;

    targetPkgs = p: runtimeLibraries ++ (with p; [
      xdg-utils git cacert bubblewrap
    ]);

    # /usr/lib points to /usr/lib64 on both supported systems. This mount-local
    # symlink preserves the original app path without touching host /usr.
    extraBuildCommands = ''
      ln -s ${payload}/lib/chatgpt "$out/usr/lib64/chatgpt"
    '';

    extraPreBwrapCmds = ''
      plugins_cache="$(${preparePlugins}/bin/chatgpt-prepare-plugins)" || exit "$?"
    '';
    extraBwrapArgs = [
      ''--ro-bind "$plugins_cache" "${payload}/lib/chatgpt/resources/plugins/openai-bundled"''
    ];

    profile = ''
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      export XDG_DATA_DIRS="${payload}/share:''${XDG_DATA_DIRS:-}"
    '';

    runScript = pkgs.writeShellScript "chatgpt-run" ''
      exec /usr/lib/chatgpt/ChatGPT "$@"
    '';

    extraInstallCommands = ''
      cp -r ${payload}/share "$out/share"
      chmod -R u+w "$out/share"
      substituteInPlace "$out/share/applications/chatgpt.desktop" \
        --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt %U" \
        --replace-fail 'x-scheme-handler/http;x-scheme-handler/https;' ""
    '';

    passthru = { inherit payload source; };
    meta = meta // { mainProgram = "chatgpt"; };
  };
in {
  inherit payload;
  # Native development/validation is scoped to ARM64. Keep the existing,
  # unvalidated x86-64 definition as it was.
  app = if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then native.app else fhs;
  nativeShell = native.shell;
  shell = fhs.override {
    executableName = "chatgpt-fhs-shell";
    runScript = "bash";
    extraInstallCommands = "";
    meta = meta // { mainProgram = "chatgpt-fhs-shell"; };
  };
}
