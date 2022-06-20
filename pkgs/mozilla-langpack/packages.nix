{
  callPackage,
  recurseIntoAttrs,
  firefox,
  firefox-esr,
  thunderbird,
}: let
  langpackPackages = args: recurseIntoAttrs (callPackage ./langpack.nix args);
in {
  firefox-langpack = langpackPackages {mozillaApp = firefox;};
  firefox-esr-langpack = langpackPackages {mozillaApp = firefox-esr;};
  thunderbird-langpack = langpackPackages {mozillaApp = thunderbird;};
}
