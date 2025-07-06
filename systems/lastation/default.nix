toplevel @ {
  inputs,
  lib,
  withSystem,
  meta,
  ...
}: {
  flake.nixosConfigurations.lastation = withSystem "x86_64-linux" ({self', ...}: let
    pkgs = self'.legacyPackages.default;
  in
    lib.nixosSystem {
      inherit (pkgs) lib;

      modules = with inputs; [
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager

        /*
        home manager
        */
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          environment.pathsToLink = ["/share/xdg-desktop-portal" "/share/applications"];
        }

        ./conf
      ];
    });
}
