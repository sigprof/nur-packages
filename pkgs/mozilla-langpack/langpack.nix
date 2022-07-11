{
  mozillaApp,
  callPackage,
  lib,
  stdenv,
  fetchurl,
}: let
  inherit (builtins) head match;
  inherit (lib) optionalString;

  supportedApps = {
    firefox = {
      fullName = "Firefox";
      addonIdSuffix = "firefox.mozilla.org";
      extensionDir = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
    };
    thunderbird = {
      fullName = "Thunderbird";
      addonIdSuffix = "thunderbird.mozilla.org";
      extensionDir = "{3550f703-e582-4d05-9a08-453d09bdfdc6}";
    };
  };

  mozillaPlatforms = {
    i686-linux = "linux-i686";
    x86_64-linux = "linux-x86_64";
  };

  sources = lib.importJSON ./sources.json;

  app =
    supportedApps.${mozillaApp.pname}
    // rec {
      name = mozillaApp.pname;
      version = lib.getVersion mozillaApp;
      major = head (match "([^.]+)\\..*" version);
      isESR = (match ".*esr" version) != null;
      majorKey = major + optionalString isESR "esr";
      arch = mozillaPlatforms.${mozillaApp.system} or "";
      langpackBaseName = "${name}${optionalString isESR "-esr"}-langpack";
    };

  langpacks = sources.${app.name}.${app.majorKey}.${app.arch} or {};

  fetchLangpack = lang: let
    langpack = langpacks.${lang};
  in
    fetchurl {
      name = "${app.name}-langpack-${lang}-${langpack.version}-${app.arch}.xpi";
      inherit (langpack) url hash;
    };

  buildLangpack = appLanguage: let
    addonId = "langpack-${appLanguage}@${app.addonIdSuffix}";
    langpack = langpacks.${appLanguage};
    langpackPackage = stdenv.mkDerivation {
      name = "${app.name}-langpack-${appLanguage}-${langpack.version}";
      src = fetchLangpack appLanguage;

      meta = {
        inherit (mozillaApp.meta) homepage license platforms;
        description = "${app.fullName} language pack for the '${appLanguage}' language.";
      };

      preferLocalBuild = true;
      allowSubstitutes = false;

      buildCommand = ''
        dst="$out/share/mozilla/extensions/${app.extensionDir}"
        mkdir -p "$dst"
        install -v -m644 "$src" "$dst/${addonId}.xpi"
      '';
    };
  in
    langpackPackage;

  makeLangpack = appLanguage: _:
    lib.nameValuePair "${app.langpackBaseName}-${appLanguage}" (buildLangpack appLanguage);
in
  lib.mapAttrs' makeLangpack langpacks
