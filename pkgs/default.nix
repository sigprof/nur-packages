{
  pkgs,
  lib,
  callPackage,
  ...
}: let
  inherit (lib) filterAttrs isDerivation;
in
  {
    cosevka = callPackage ./cosevka {};
    terminus-font-custom = callPackage ./terminus-font-custom {};
    virt-manager = callPackage ./virt-manager {};
  }
  // filterAttrs (n: isDerivation) (callPackage ./mozilla-langpack/packages.nix {})
