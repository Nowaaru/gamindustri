{
  description = "Description for the project";

  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
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
    flake-parts,
    flake-utils,
    nixpkgs-lib,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} ({
      withSystem,
      flake-parts-lib,
      ...
    }: let
      lib = nixpkgs-lib.outputs.lib.extend (_: _: {
        flake-parts = flake-parts-lib;
        gamindustri = {
          mkFlake = flake-parts.lib.mkFlake {inherit inputs;};
        };
      });
    in {
      systems = flake-utils.lib.allSystems;

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
        ...
      }: let
        default = import inputs.nixpkgs {
          inherit system overlays config;
        };
        overlays = import ./overlays withSystem (inputs
          // {
            inherit (default) lib;
          });
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

        legacyPackages = {
          inherit default;

          stable = import inputs.nixpkgs-mirror {
            inherit system overlays config;
          };

          master = import inputs.nixpkgs-master {
            inherit system overlays config;
          };

          nur = import inputs.nurpkgs {
            pkgs = self'.legacyPackages.default;
            nurpkgs = import inputs.nixpkgs {
              inherit system config;
            };
          };
        };
      };
    });
}
