{
  description = "Description for the project";

  inputs = {
    flake-parts.follows = "gamindustri-utils/flake-parts";
    flake-utils.follows = "gamindustri-utils/flake-utils";
    lanzaboote.url = "github:nix-community/lanzaboote";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "gamindustri-utils/nixpkgs";
    };

    gamindustri-utils = {
      type = "indirect";
      id = "nix-utils";
    };

    gamindustri-residents = {
      type = "indirect";
      id = "gamindustri-residents";
    };
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
      config,
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
                flake-config = config;
              };
            }
          ];
        }).config) (lib.attrsets.filterAttrs (k: v: v == "directory" && (builtins.pathExists (./systems/${k} + "/meta.nix"))) (builtins.readDir ./systems));
      systemImports = lib.attrsets.foldlAttrs (
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
                          flake.nixosConfigurations.${k} = (thisSystem
                            // {
                              config =
                                if userHasThisArchitecture
                                then thisSystem.config
                                else thisSystem.config;
                            }).extendModules {modules = [{_module.args = evaluatedSystemOptions.${k}.specialArgs;}];};
                        }
                        else {}
                      )
                    ];
                  })
              else {}
          )
      ) [] (lib.attrsets.filterAttrs (k: _: k != "default.nix") (builtins.readDir ./systems));
    in {
      imports = systemImports;

      systems =
        lib.attrsets.foldlAttrs (
          acc: _: v:
            acc ++ v.systems
        ) []
        evaluatedSystemOptions;

      perSystem = {
        system,
        self',
        inputs',
        ...
      }: let
      in rec {
        inherit (inputs'.gamindustri-utils) legacyPackages;
        _module.args.pkgs = legacyPackages.default;
      };

      flake.flakeModules.default = _: {
        imports = systemImports;
      };
    });
}
