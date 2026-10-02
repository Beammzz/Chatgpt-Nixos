{ self }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.chatgpt;
  launcher = pkgs.writeShellScriptBin "chatgpt" ''
    # Owl rejects Chromium's "auto" value. Select an explicit platform, while
    # allowing configured arguments or the caller to choose one themselves.
    platform_args=()
    platform_set=false
    for arg in ${lib.escapeShellArgs cfg.extraArgs} "$@"; do
      case "$arg" in
        --ozone-platform|--ozone-platform=*) platform_set=true ;;
      esac
    done
    if [[ "$platform_set" == false ]]; then
      case "''${XDG_SESSION_TYPE:-}" in
        wayland) platform_args+=(--ozone-platform=wayland) ;;
        x11) platform_args+=(--ozone-platform=x11) ;;
        *)
          if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
            platform_args+=(--ozone-platform=wayland)
          else
            platform_args+=(--ozone-platform=x11)
          fi
          ;;
      esac
    fi
    ${lib.optionalString (cfg.codexHome != null) ''
      export CODEX_HOME=${lib.escapeShellArg cfg.codexHome}
      ${pkgs.coreutils}/bin/mkdir -p "$CODEX_HOME"
    ''}
    exec ${lib.getExe cfg.package} "''${platform_args[@]}" ${lib.escapeShellArgs (
      cfg.extraArgs ++ lib.optional (cfg.userDataDir != null) "--user-data-dir=${cfg.userDataDir}"
    )} "$@"
  '';
  desktop = pkgs.makeDesktopItem {
    name = "chatgpt";
    desktopName = "ChatGPT";
    genericName = "AI assistant";
    comment = "ChatGPT by OpenAI";
    exec = "${launcher}/bin/chatgpt %U";
    icon = "${cfg.package}/share/pixmaps/chatgpt.png";
    categories = [ "Utility" "Development" ];
    startupNotify = true;
    mimeTypes = [ "x-scheme-handler/codex" ];
  };
in {
  options.programs.chatgpt = {
    enable = lib.mkEnableOption "the ChatGPT desktop prototype";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt;
      description = "ChatGPT package to launch.";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Launcher arguments. By default the wrapper selects native Wayland in a Wayland session; set --ozone-platform=x11 for XWayland.";
    };
    codexHome = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute Codex state directory, or null to use the existing user profile and login.";
    };
    userDataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute Chromium profile directory, or null for the app default.";
    };
    registerLoginHandler = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register ChatGPT as the default handler for codex: URIs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
        message = "The ChatGPT Home Manager prototype currently targets aarch64-linux.";
      }
      {
        assertion = builtins.all (path: path == null || lib.hasPrefix "/" path)
          [ cfg.codexHome cfg.userDataDir ];
        message = "ChatGPT profile paths must be absolute.";
      }
    ];
    home.packages = [ launcher desktop ];
    xdg.mimeApps = lib.mkIf cfg.registerLoginHandler {
      enable = lib.mkDefault true;
      defaultApplications."x-scheme-handler/codex" = lib.mkDefault [ "chatgpt.desktop" ];
    };
  };
}
