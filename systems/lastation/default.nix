toplevel @ { withSystem, inputs }: {
  flake.nixosConfigurations.lastation = withSystem "x86_64-linux" ({self', ...}: let
    pkgs = self'.legacyPackages.default;
    specialArgs = {
      inherit (self'.legacyPackages) nur unstable stable;
      inherit (pkgs) lib;
      inherit inputs;
    };
  in
    inputs.nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      inherit (pkgs) lib;

      modules = with inputs; [
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        /*
        readonly pkgs
        */
        {
          imports = [
            nixpkgs.nixosModules.readOnlyPkgs
          ];

          nixpkgs.pkgs = pkgs.lib.mkForce pkgs;
        }
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
