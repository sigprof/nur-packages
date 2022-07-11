{
  pkgs,
  inputs,
  callPackage,
  ...
}: let
  inherit (inputs.flake-utils.lib) filterPackages;
in
  {
    cosevka = callPackage ./cosevka {};
    terminus-font-custom = callPackage ./terminus-font-custom {};
    virt-manager = callPackage ./virt-manager {};
  }
  // (callPackage ./mozilla-langpack/packages.nix {inherit inputs;})
