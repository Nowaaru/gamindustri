lib @ {

  mkIf,
  mkMerge, 
  mkEnableOption,
  mkOption,
  allSystems,
  systemImportArgs,
  ...
}: 
baseModule @ {config, ... }: 
{
  options = with lib.types; 
  {
    system = mkOption {
        type = submodule (systemModule@{ config, ...}: {
            imports = [];

            options = {
                file = mkOption {
                    description = "The path to the system's 'default.nix' file.";
                    type = path;
                };

                description = mkOption {
                  description = "The description for this System.";
                  type = nullOr str;
                  default = "A NixOS system.";
                };

                architecture = mkOption {
                  description = "The system architecture that this configuration should be run on.";
                  type = nullOr (enum allSystems);
                  default = null;
                };

                specialArgs = mkOption {
                  description = "Arguments to be layed over all modules.";
                  type = attrs;
                  default = {};
                };

                baseModules = mkOption {
                    description = "Intrinsic modules to the system configuration.";
                    type = listOf (oneOf [(functionTo attrs) attrs]); # TODO: fix this module type
                };
            };


            config.baseModules = [ 
                { nixpkgs.pkgs = lib.mkForce baseModule.config.repositories.main; } 
            ];

            config.specialArgs = lib.mkMerge
                [
                    { 
                        # pkgs = baseModule.config.repositories.main; 
                        meta = baseModule;
                    }
                    baseModule.config.repositories.fallback
                    systemImportArgs
                ];
        });

    };


    packages = mkOption {
        type = submodule (packageModule@{ config, ...}:
        {
            readonly = mkOption {
                type = submodule (readonlyModule@{ config, ...}: {
                    options.enable = mkEnableOption "readonly packages for this system.";

                    config = mkIf readonlyModule.enable {
                        system.baseModules = [
                            ({}: {
                                imports = [
                                    inputs.gamindustri-utils.inputs.nixpkgs.nixosModules.readOnlyPkgs
                                ];
                            })
                        ];         
                    };
                });
            };
        });
    };

    repositories = {
      main = mkOption {
        description = "Primary repositiory of utilities and packages to be added to as 'pkgs'";
        type = lib.types.pkgs;
      };

      fallback = mkOption {
        description = "Fallback repositories of utilities and packages to be added to 'specialArgs'";
        type = attrsOf lib.types.pkgs;
        default = {};
      };
    };
  };

  config = {};
}
