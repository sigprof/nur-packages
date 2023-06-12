let
  functions = import ./functions.nix;
  presets = import ./presets.nix;
in
  {
    pkgs,
    lib,
    callPackage,
  }: let
    inherit (lib) mapAttrs' nameValuePair optionalAttrs;

    # Make a language pack package for the specified Mozilla-originated app and
    # language.
    #
    # Required arguments:
    # - `mozApp`: The app package for which the language pack needs to be made.
    # - `mozLanguage`: The language name in the format used by Mozilla.
    #
    # Optional arguments:
    # - `mozAppName`: The app name (normally derived from `mozApp`, but can be
    #   specified explicitly in case the app was renamed, but is actually still
    #   compatible with language packs for the original app).
    # - `mozAppVersion`: The app version (normally derived from `mozApp`, but
    #   can be overridden if a modified app uses an incompatible version
    #   format).
    #
    # Optional arguments for some really special cases:
    # - `mozSupportedApps`: The set of supported Mozilla apps (currently only
    #   `firefox` and `thunderbird` are supported by default).
    # - `mozPlatforms`: The set which provides the mapping from the Nix system
    #   name to the platform name used by Mozilla products.
    # - `mozLangpackSources`: The set of known language pack sources; usually
    #   supplied by the package, but an override may be supplied for some
    #   really custom cases.
    #
    # Any arguments with names not listed above are passed to `callPackage`.
    #
    makeMozillaLangpack = args @ {
      mozApp,
      mozLanguage,
      mozAppName ? mozApp.pname,
      mozAppVersion ? lib.getVersion mozApp,
      mozSupportedApps ? presets.mozSupportedApps,
      mozPlatforms ? presets.mozPlatforms,
      mozLangpackSources ? presets.mozLangpackSources,
      ...
    }:
      callPackage ./langpack.nix (args
        // {
          # Arguments with default values need to be passed explicitly.
          inherit mozAppName mozAppVersion mozSupportedApps mozPlatforms mozLangpackSources;
        });

    # Make language pack packages for the specified app and all available
    # languages.
    langpackPackagesFor = mozApp: let
      app = functions.getAppInfo (presets // {inherit lib mozApp;});
      langpacks = presets.mozLangpackSources.${app.name}.${app.majorKey}.${app.arch} or {};
      packageName = mozLanguage: "${app.langpackBaseName}-${mozLanguage}";
      package = mozLanguage: makeMozillaLangpack {inherit mozApp mozLanguage;};
    in
      lib.mapAttrs' (n: v: nameValuePair (packageName n) (package n)) langpacks;

    integrateMozillaLangpackPackages = args @ {
      mozApp,
      mozLangpackPackages,
    }: let
      mozLangpackFiles = map (p: "${p}/${p.mozExtensionPath}") mozLangpackPackages;
      mozApp' = mozApp.override {
        extraPrefs = ''
          pref("intl.locale.matchOS", true);
          pref("intl.locale.requested", "");
        '';
      };
    in
      mozApp'.overrideAttrs (final: prev: {
        # The search for `mozilla.cfg` is done because it's hard to determine
        # the value of `libName` that has been passed to the wrapper.
        buildCommand =
          prev.buildCommand
          + ''
            mozilla_cfg="$(find "$out/lib" -name mozilla.cfg)"
            [ -e "$mozilla_cfg" ] || {
              echo "Cannot find mozilla.cfg in $out/lib" 1>&2
              exit 1
            }
            extensions_dir="''${mozilla_cfg%/*}/distribution/extensions"
            mkdir -p "$extensions_dir"
            for ext in ${toString mozLangpackFiles}; do
              ln -sLt "$extensions_dir/" "$ext"
            done
          '';
      });

    integratedPackagesFor = mozApp: appName: langpackPackages: let
      packageName = lp: "${appName}-${lp.mozLanguage}";
      package = lp:
        integrateMozillaLangpackPackages {
          inherit mozApp;
          mozLangpackPackages = [lp];
        };
    in
      lib.mapAttrs' (n: v: nameValuePair (packageName v) (package v)) langpackPackages;

    allPackagesFor = appName: let
      mozApp = pkgs.${appName};
      langpackPackages = langpackPackagesFor mozApp;
    in
      langpackPackages // (integratedPackagesFor mozApp appName langpackPackages);
  in {
    packages =
      {
        # Always export `makeMozillaLangpack`, even if known Mozilla-originated
        # apps are not available (maybe someone wants to override the set of
        # supported Mozilla apps).
        inherit makeMozillaLangpack;
      }
      # Export language pack packages for all available Mozilla-originated
      # packages from the supported set and all available languages.
      // optionalAttrs (pkgs ? firefox) (allPackagesFor "firefox")
      // optionalAttrs (pkgs ? firefox-esr) (allPackagesFor "firefox-esr")
      // optionalAttrs (pkgs ? thunderbird) (allPackagesFor "thunderbird");
  }
