{
  description = "Prototype packaging of the official ChatGPT Linux desktop app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      prototypes = forAllSystems (system:
        import ./package.nix {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = package:
              builtins.elem (nixpkgs.lib.getName package) [ "chatgpt" "chatgpt-payload" ];
          };
        });
    in {
      homeManagerModules.default = import ./home-manager.nix { inherit self; };

      packages = forAllSystems (system: {
        default = prototypes.${system}.app;
        chatgpt = prototypes.${system}.app;
        payload = prototypes.${system}.payload;
        fhs-shell = prototypes.${system}.shell;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${prototypes.${system}.app}/bin/chatgpt";
          meta.description = "Launch the official ChatGPT desktop prototype";
        };
        fhs-shell = {
          type = "app";
          program = "${prototypes.${system}.shell}/bin/chatgpt-fhs-shell";
          meta.description = "Open the ChatGPT prototype's diagnostic FHS shell";
        };
      });
    };
}
