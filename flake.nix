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
      inherit (flake-parts-lib) importApply;
      systemImportArgs = let
        newImportApply = source: args:
          importApply source (systemImportArgs // args);
      in {
        inherit inputs lib withSystem;
        importApply = newImportApply;
        self = self.outPath;
        flake-config = self;
      };

      evaluatedSystemOptions =
        lib.attrsets.mapAttrs (k: _: (lib.gamindustri.systems.evalSystemMetafile ./systems/${k}/meta.nix systemImportArgs).config)
        (lib.attrsets.filterAttrs (k: v: v == "directory" && (builtins.pathExists (./systems/${k} + "/meta.nix"))) (builtins.readDir ./systems));

      systemImports = lib.attrsets.foldlAttrs (
        a: k: _:
          a
          ++ lib.lists.singleton (
            let
              metaPathExists = builtins.pathExists (./systems/${k} + "/meta.nix");
              metafile = lib.trivial.warnIfNot metaPathExists "meta file for system '${k}' could not be found" metaPathExists;
              imported =
                if metafile
                then
                  flake-parts-lib.importApply ./systems/${k}/default.nix ((evaluatedSystemOptions.${k}.system.specialArgs)
                    // systemImportArgs
                    // {pkgs = evaluatedSystemOptions.${k}.repositories.main;}
                    // {meta = evaluatedSystemOptions.${k};})
                else {};

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
                  thisSystem = (importedContents.flake.nixosConfigurations.${builtins.elemAt (builtins.attrNames allConfigurations) 0}).extendModules {
                    modules = evaluatedSystemOptions.${k}.system.baseModules;
                  };

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
                        let
                          systemIsConfiguration = nixosSystem:
                            lib.throwIfNot (((nixosSystem ? "_type") && (nixosSystem ? "class"))
                              && (nixosSystem._type == "configuration" && nixosSystem.class == "nixos")) "expected type 'nixosSystem', got '${builtins.typeOf nixosSystem}'";

                          extractSystemVitals = nixosSystem: newSystemArgs:
                            systemIsConfiguration nixosSystem {} // newSystemArgs;
                        in
                          if (lib.assertMsg (configurationAmount == 1) "system-file ${k} must export exactly one configuration and no more.")
                          then
                            (
                              let
                                systemMeta = evaluatedSystemOptions.${k};
                              in {
                                flake.nixosConfigurations.${k} = systemMeta.repositories.main.lib.nixosSystem (extractSystemVitals thisSystem {
                                  inherit (systemMeta.system) specialArgs;
                                  inherit (systemMeta.repositories.main) lib;
                                  pkgs = systemMeta.repositories.main;

                                  modules =
                                    (lib.lists.dropEnd 1 (lib.lists.filter (v:
                                        if (builtins.isAttrs v) && (v ? "_file")
                                        then (v._file != systemMeta.system.file)
                                        else (v != systemMeta.system.file))
                                      (
                                        if thisSystem ? "class"
                                        then thisSystem._module.args.modules
                                        else thisSystem.modules
                                      )))
                                    ++ systemMeta.system.baseModules;
                                });
                              }
                            )
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
            acc ++ (lib.lists.singleton v.system.architecture)
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
      };

      flake.flakeModules.default = _: {
        imports = systemImports;
      };
    });
}
