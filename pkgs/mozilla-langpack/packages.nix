{
  inputs,
  callPackage,
  firefox,
  firefox-esr,
  thunderbird,
}: let
  inherit (inputs.flake-utils.lib) filterPackages;
  langpackPackages = args: (callPackage ./langpack.nix args);
in
  {}
  // langpackPackages {mozillaApp = firefox;}
  // langpackPackages {mozillaApp = firefox-esr;}
  // langpackPackages {mozillaApp = thunderbird;}
