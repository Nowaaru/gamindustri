{
  description = "Description for the project";

  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-utils = {
      url = "github:nowaaru/nix-utils";
    };

    nixpkgs-mirror.url = "github:nixos/nixpkgs/release-25.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nurpkgs.url = "github:nix-community/NUR";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";

    nixgl.url = "github:nix-community/nixGL";
    lanzaboote.url = "github:nix-community/lanzaboote";
  };

  outputs = inputs @ {
    self,
    flake-utils,
    nix-utils,
    ...
  }: let
    inherit (nix-utils) lib;
  in
    lib.gamindustri.mkFlake ({
      withSystem,
      flake-parts-lib,
      ...
    }: let

      imports = lib.attrsets.foldlAttrs (
        a: k: _:
          a
          ++ lib.lists.singleton (
            let
              metaPathExists = builtins.pathExists (./systems/${k} + "/meta.nix");
              metafile = lib.trivial.warnIfNot metaPathExists "meta file for system '${k}' could not be found" metaPathExists;
              imported = flake-parts-lib.importApply ./systems/${k}/default.nix {inherit inputs withSystem;};
              importedContents =
                if (lib.asserts.assertMsg ((builtins.length imported.imports) == 1) "system-file ${k} should not have more than one import")
                then builtins.elemAt imported.imports 0
                else {};
            in
              if metafile
              then
                (let
                  allConfigurations = importedContents.flake.nixosConfigurations;
                  configurationAmount = builtins.length (builtins.attrNames allConfigurations);
                  thisSystem = importedContents.flake.nixosConfigurations.${builtins.elemAt (builtins.attrNames allConfigurations) 0};

                  mkBuildPlatformError = wrongPlatform: rightPlatform: "cannot build configuration '${k}'; architecture '${rightPlatform}' is needed, but i am a '${wrongPlatform}'.";

                  evaluatedOptions = lib.modules.evalModules {
                    modules = import ./systems/${k}/meta.nix {
                      inherit self inputs lib;
                    };
                  };

                  userArchitecture = lib.strings.trim (builtins.readFile (thisSystem.pkgs.runCommandLocal "architecture-check-${k}" {} ''
                    uname -m > $out;
                  ''));

                  userHasThisArchitecture = lib.assertMsg (lib.strings.hasPrefix userArchitecture thisSystem.pkgs.stdenv.system) (mkBuildPlatformError userArchitecture thisSystem.pkgs.stdenv.system);
                in (imported
                  // {
                    imports = [
                      (
                        if (lib.assertMsg (configurationAmount == 1) "system-file ${k} must export exactly one configuration and no more.")
                        then {
                          flake.nixosConfigurations.${k} =
                            thisSystem
                            // {
                              config =
                                if userHasThisArchitecture
                                then thisSystem.config
                                else thisSystem.config;
                              _module =
                                thisSystem._module
                                // {
                                  specialArgs = thisSystem.specialArgs // metafile.specialArgs;
                                };
                            };
                        }
                        else {}
                      )
                    ];
                  }))
              else {}
          )
      ) [] (lib.attrsets.filterAttrs (k: _: k != "default.nix") (builtins.readDir ./systems));

      perSystem = {
        system,
        self',
        inputs',
        ...
      }: let
        inherit (inputs'.nix-utils.legacyPackages) default;

        config = {
          allowUnfree = true;
          permittedInsecurePackages = [
            "dotnet-sdk-6.0.428"
            "dotnet-sdk-7.0.410"
            "dotnet-runtime-7.0.20"
          ];
        };
      in rec {
        _module.args.pkgs = legacyPackages.default;
        inherit (self'.nix-utils) legacyPackages;
      };
    });
}
