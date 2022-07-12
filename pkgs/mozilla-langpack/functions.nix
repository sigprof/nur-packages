{
  getAppInfo = {
    lib,
    mozSupportedApps,
    mozPlatforms,
    mozApp,
    mozAppName ? mozApp.pname,
    mozAppVersion ? lib.getVersion mozApp,
    ...
  }:
    mozSupportedApps.${mozAppName}
    // rec {
      name = mozAppName;
      version = mozAppVersion;
      major = builtins.head (builtins.match "([^.]+)\\..*" version);
      isESR = (builtins.match ".*esr" version) != null;
      majorKey = major + lib.optionalString isESR "esr";
      arch = mozPlatforms.${mozApp.system} or "";
      langpackBaseName = "${name}${lib.optionalString isESR "-esr"}-langpack";
    };
}
