lib @ {
  mkIf,
  mkMerge, 
  mkEnableOption,
  mkOption,
  allSystems,
  ...
}: 
moduleParemeters @ {config, ... }: 
let 
        syscfg = config.system; 
    in 
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

                architectures = mkOption {
                  description = "The potential system architectures that this configuration can be run on. Cannot be set if 'system' is set.";
                  type = if (builtins.isString config.system.architecture) then listOf (enum [ config.system.architecture ]) else (listOf (enum allSystems));
                  default = [ config.system.architecture ];
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
            };
        });
    };


    packages = mkOption {
        type = submodule (packageModule@{ config, ...}:
        {
            readonly = mkOption {
                type = submodule (readonlyModule@{ config, ...}: {
                    options.enable = mkEnableOption "readonly packages for this system.";

                    config = mkIf (config.packages.readonly.enable) {
                        modules = [
                            ({config, ...}: {
                                imports = [
                                    inputs.gamindustri-utils.inputs.nixpkgs.nixosModules.readOnlyPkgs
                                ];

                                nixpkgs.pkgs = moduleParameters.config.repositories.main;
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
        type = package;
      };
      fallback = mkOption {
        description = "Fallback repositories of utilities and packages to be added to 'specialArgs'";
        type = attrsOf package;
        default = {};
      };
    };
  };

  config = {};
}
