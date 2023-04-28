{
  description = "Personal NUR repository of @sigprof";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.inputs.nixpkgs-stable.follows = "nixpkgs";
    pre-commit-hooks.inputs.flake-utils.follows = "flake-utils";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    pre-commit-hooks,
    devshell,
    ...
  }:
    {
      lib = import ./lib inputs;
      nixosModules = import ./modules {inherit self inputs;};
      nixosConfigurations = import ./hosts {inherit self inputs;};
      overlays.default = import ./overlay.nix;
    }
    // (
      flake-utils.lib.eachDefaultSystem (system: let
        inherit (flake-utils.lib) filterPackages flattenTree;
        pkgs = nixpkgs.legacyPackages.${system};
        legacyPackages = (pkgs.callPackage ./pkgs {inherit inputs;}).packages;
        packages = filterPackages system (flattenTree legacyPackages);
      in {
        inherit packages legacyPackages;
      })
    )
    // (
      let
        checkedSystems = with flake-utils.lib.system; [
          x86_64-linux
          x86_64-darwin
          aarch64-linux
          aarch64-darwin
          # No `i686-linux` because `pre-commit-hooks` does not evaluate
        ];
      in
        flake-utils.lib.eachSystem checkedSystems (system: let
          nixos-unstable = inputs.nixos-unstable.legacyPackages.${system};
          alejandra = nixos-unstable.alejandra;
        in {
          checks =
            {
              pre-commit = pre-commit-hooks.lib.${system}.run {
                src = ./.;
                hooks = {
                  alejandra.enable = true;
                };
                tools.alejandra = alejandra;
              };
            }
            // nixos-unstable.lib.optionalAttrs (nixos-unstable.telegram-desktop.meta.available or false) {
              telegram-desktop = nixos-unstable.pkgs.stdenvNoCC.mkDerivation {
                name = "telegram-desktop-check";
                dontBuild = true;
                doCheck = true;
                src = ./.;
                nativeBuildInputs = [nixos-unstable.which nixos-unstable.telegram-desktop];
                checkPhase = ''
                  if file "$(which telegram-desktop)" | grep -qs "too large"; then
                    echo "error: telegram-desktop wrapper is corrupted" 1>&2
                    exit 1
                  fi
                '';
                installPhase = ''
                  mkdir "$out"
                '';
              };
            }
            // (
              let
                inherit (nixpkgs.lib) filterAttrs mapAttrs mapAttrs' nameValuePair pipe;
                inherit (self.legacyPackages.${system}.lib) forceCached;
              in
                pipe self.nixosConfigurations [
                  (mapAttrs' (name: host: (nameValuePair ("host/" + name) host.config.system.build.toplevel)))
                  (filterAttrs (_: drv: drv.system == system))
                  (mapAttrs (_: drv: forceCached drv))
                ]
            );

          devShells.default = devshell.legacyPackages.${system}.mkShell {
            name = "sigprof/nur-packages";
            motd = "{6}🔨 Welcome to {bold}sigprof/nur-packages{reset}";
            packages = [
              alejandra
            ];
            devshell.startup.pre-commit-hooks.text = self.checks.${system}.pre-commit.shellHook;
          };
        })
    );
}
