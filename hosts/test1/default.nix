{
  self,
  inputs,
  ...
}: let
  system = "x86_64-linux";
in
  inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.default

      ({pkgs, ...}: {
        system.stateVersion = "22.05";
        networking.hostName = "test1";
        fileSystems."/".device = "/dev/sda1";
        boot.loader.grub.device = "/dev/sda";

        sigprof.hardware.gpu.driver.nvidia.legacy_340.enable = true;

        services.printing.enable = true;
        sigprof.hardware.printers.driver.hplip.enable = true;
        sigprof.hardware.printers.driver.hplip.enablePlugin = true;

        hardware.sane.enable = true;
        sigprof.hardware.sane.backend.epkowa.enable = true;

        sigprof.i18n.ru_RU.enable = true;

        environment.systemPackages = [
          (pkgs.tor-browser-bundle-bin.overrideAttrs (old: {
            version = "11.0.13";
            src = pkgs.fetchurl {
              url = "https://archive.torproject.org/tor-package-archive/torbrowser/11.0.13/tor-browser-linux64-11.0.13_en-US.tar.xz";
              sha256 = "03pzwzgikc43pm0lga61jdzg46fanmvd1wsnb2xkq0y1ny8gsqfz";
            };
          }))
          self.packages.${system}.virt-manager
        ];

        fonts.fonts = [
          self.packages.${system}.cosevka
        ];
      })
    ];
  }
