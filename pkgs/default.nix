{
  pkgs,
  lib,
  callPackage,
  ...
}:
{
  cosevka = callPackage ./cosevka {};
  terminus-font-custom = callPackage ./terminus-font-custom {};
  virt-manager = callPackage ./virt-manager {};
}
// import ./mozilla-langpack/packages.nix {inherit pkgs lib callPackage;}
