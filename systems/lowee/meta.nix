{
  self,
  inputs,
  lib,
  ...
} @ args: {
  description = "The primary workstation for Blanc.";
  systems = ["aarch64-linux"];

  specialArgs = {
    inherit inputs lib;
  };

  repositories = {
    inherit (inputs) nur unstable stable master default;
  };
}
