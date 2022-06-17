{ defaultMozillaApp, appLanguage }:
{ pkgs, callPackage, lib, stdenv, fetchurl, mozillaApp ? defaultMozillaApp }:

let
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

  allLangpacks = import ./langpack-list.nix;

  app = supportedApps.${mozillaApp.pname} // {
    name = mozillaApp.pname;
    version = lib.getVersion mozillaApp;
    arch = mozillaPlatforms.${mozillaApp.system};
  };

  langpacks = allLangpacks.${app.name}.${app.version}.${app.arch};

  fetchLangpack = lang: fetchurl {
    name = "${app.name}-langpack-${lang}-${app.version}-${app.arch}.xpi";
    url = "https://releases.mozilla.org/pub/${app.name}/releases/${app.version}/${app.arch}/xpi/${lang}.xpi";
    sha256 = langpacks.${lang}.sha256;
  };

  buildLangpack =
    appLanguage:
    let
      addonId = "langpack-${appLanguage}@${app.addonIdSuffix}";
      langpackPackage =
        { stdenv, mozillaApp }:
        stdenv.mkDerivation {
          name = "${app.name}-langpack-${appLanguage}-${app.version}";
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
    lib.makeOverridable langpackPackage;

  genLangpack = appLanguage: callPackage (buildLangpack appLanguage) { };

in
{
  "${app.name}-langpack-${appLanguage}" = genLangpack appLanguage;
}
