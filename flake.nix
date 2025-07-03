{
  description = "Description for the project";

  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gamindustri-utils = {
      type = "indirect";
      id = "nix-utils";
    };

    flake-parts.follows = "gamindustri-utils/flake-parts";
    flake-utils.follows = "gamindustri-utils/flake-utils";
  };

  outputs = inputs @ {
    self,
    flake-utils,
    flake-parts,
    gamindustri-utils,
    ...
  }: let
    lib = gamindustri-utils.lib.extend (super: prev: {
      inherit (gamindustri-utils.inputs.nixpkgs.lib) nixosSystem;
    });
  in
    flake-parts.lib.mkFlake {inherit inputs;} ({
      withSystem,
      flake-parts-lib,
      ...
    }: let
      evaluatedSystemOptions = lib.attrsets.mapAttrs (k: _:
        (lib.modules.evalModules {
          modules = [
            (import ./schema/meta.nix {
              inherit (flake-utils.lib) allSystems;
              inherit (lib.options) mkOption;
              inherit (lib) types mkIf mkMerge;
            })
            {
              config = import ./systems/${k}/meta.nix {
                inherit self inputs lib;
              };
            }
          ];
        }).config) (lib.attrsets.filterAttrs (k: v: v == "directory" && (builtins.pathExists (./systems/${k} + "/meta.nix"))) (builtins.readDir ./systems));
    in {
      systems =
        lib.attrsets.foldlAttrs (
          acc: _: v:
            acc ++ v.systems
        ) []
        evaluatedSystemOptions;

      imports = lib.attrsets.foldlAttrs (
        a: k: _:
          a
          ++ lib.lists.singleton (
            let
              metaPathExists = builtins.pathExists (./systems/${k} + "/meta.nix");
              metafile = lib.trivial.warnIfNot metaPathExists "meta file for system '${k}' could not be found" metaPathExists;
              imported = flake-parts-lib.importApply ./systems/${k}/default.nix {inherit inputs lib withSystem;};
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

                  userArchitecture = lib.strings.trim (builtins.readFile (thisSystem.pkgs.runCommandLocal "architecture-check-${k}" {} ''
                    uname -m > $out;
                  ''));

                  userHasThisArchitecture = lib.assertMsg (lib.strings.hasPrefix userArchitecture (builtins.elemAt (lib.strings.split "-" thisSystem.pkgs.stdenv.system) 0)) (mkBuildPlatformError userArchitecture thisSystem.pkgs.stdenv.system);
                in
                  imported
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
                  })
              else {}
          )
      ) [] (lib.attrsets.filterAttrs (k: _: k != "default.nix") (builtins.readDir ./systems));

      perSystem = {
        system,
        self',
        inputs',
        ...
      }: let
        inherit (inputs'.gamindustri-utils.legacyPackages) default;

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
        inherit (inputs'.gamindustri-utils) legacyPackages;
      };
    });
}
