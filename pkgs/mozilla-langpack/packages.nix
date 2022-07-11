{
  pkgs,
  lib,
  callPackage,
  firefox,
  firefox-esr,
  thunderbird,
}: let
  inherit (lib) filterAttrs isDerivation;
  langpackPackages = args:
    filterAttrs (n: isDerivation) (callPackage ./langpack.nix args);
in
  {}
  // langpackPackages {mozillaApp = firefox;}
  // langpackPackages {mozillaApp = firefox-esr;}
  // langpackPackages {mozillaApp = thunderbird;}
