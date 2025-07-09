# TODO: integrate properly with evalUserMetaFile
{
  inputs,
  pkgs,
  lib,
  meta,
  ...
}: let
  inherit (meta.system) usersDir;
in {
  users.users = with lib.attrsets;
    mapAttrs (k: _: let
      user-meta =
        (lib.gamindustri.systems.evalUserMetaFile "${usersDir}/${k}/meta.nix" {}).config;
    in {
      inherit (user-meta) name description shell;
      extraGroups = user-meta.groups;
      isNormalUser = true;
      packages = lib.mkForce []; # managed via home-manager
    }) (lib.attrsets.filterAttrs (dir_k: v: v == "directory" && builtins.pathExists "${usersDir}/${dir_k}/meta.nix") (builtins.readDir usersDir));
}
