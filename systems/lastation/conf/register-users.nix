{
  inputs,
  pkgs,
  lib,
  flake-config,
  ...
}: rec {
  users.users = builtins.mapAttrs (k: _:
    {
      isNormalUser = true;
      description = "user - ${k}";
      shell = pkgs.fish;
      extraGroups = ["users" "networkmanager" "wheel" "libvirtd"];
      packages = []; # managed via home-manager
    }
    // (
      let
        path = inputs.self + /users/${k}/meta.nix;
      in
        if (builtins.pathExists path)
        then (import path)
        else {}
    ))
  (lib.attrsets.filterAttrs (_: v: v == "directory") (builtins.readDir inputs.gamindustri-residents));
}
