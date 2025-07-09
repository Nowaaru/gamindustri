# TODO: integrate properly with evalUserMetaFile
{
  inputs,
  pkgs,
  lib,
  meta,
  ...
}: let
  inherit (meta.system) usersDir;
in
  lib.throwIf true "The system is not currently able to register users. Please try again later." {
    users.users = with lib.attrsets;
      mapAttrs (k: _: let
        user-meta =
          lib.gamindustri.systems.evalUserMetaFile usersDir {};
      in {
        name = attrByPath ["name"] k user-meta;
        isNormalUser = true;
        description = "user - ${k}";
        shell = pkgs.fish;
        extraGroups = ["users" "networkmanager" "wheel" "libvirtd"];
        packages = []; # managed via home-manager
      }) (lib.attrsets.filterAttrs (_: v: v == "directory") (builtins.readDir usersDir));
  }
