{callPackage, ...}: {
  packages =
    {
      cosevka = callPackage ./cosevka {};
      terminus-font-custom = callPackage ./terminus-font-custom {};
      virt-manager = callPackage ./virt-manager {};
    }
    // (callPackage ./mozilla-langpack/packages.nix {}).packages;
}
