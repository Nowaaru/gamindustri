lib @ { mkIf, mkMerge, allSystems, }: 
moduleParameters @ { config, ... }: {
  options = with lib.types; {
    description = mkOption {
        description = "The description for this System.";
        type = nullOr str;
        default = "A NixOS system.";
        required = true;
    };

    systems = mkOption {
        description = "The potential system architectures that this configuration can be run on. Cannot be set if 'system' is set.";
        type = listOf (oneOf allSystems);
        default = null;
    };

    system = mkOption {
        description = "The system architecture that this configuration should be run on.";
        type = oneOf allSystems;
        required = config.systems == null;
    };

    specialArgs = mkOption {
      description = "Arguments to be layed over all modules.";
      type = attrs;
      default = {};
      required = true;
    };

    repositories = mkOption {
        description = "Repositories of utilities and packages to be added to 'specialArgs'";
        type = attrsOf package;
        required = true;
    };
  };

  config = {
    systems = mkIf (config.system != null) (
      mkMerge [
        (mkIf (config.systems != null) config.systems)
        [ config.system ]
      ]
    );
  };
}
