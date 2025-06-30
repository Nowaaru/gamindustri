withSystem:  
{
    home-manager ? null, 
    nix-mod-manager ? null, 
    self, 
    ...
} @ inputs: (_: super: {
  lib = super.lib.extend (_: prev:
    # home-manager.lib //
      prev
      // (if (home-manager != null) then {
        # add lib.hm to my lib

        inherit (home-manager.lib) hm;
      } else {}) //(if (nix-mod-manager != null) then {

        # add lib.nnmm to lib
            inherit (inputs.nix-mod-manager.lib) nnmm;
        } else {} )//{
        inherit withSystem;

        gamindustri = import (self + /lib) (inputs
          // {
            pkgs = super;
            lib =
              prev
              // home-manager.lib
              // {  inherit withSystem; }
              // (
                if (builtins.hasAttr "config" super) && (builtins.hasAttr "lib" super.config)
                then builtins.trace "has config.lib" super.config.lib
                else {}
              );
          });
          
      });
  # override with
})
