{
  flake-config,
  inputs,
  ...
}: {
  description = "The primary workstation for Noire.";
  systems = ["x86_64-linux"];

  specialArgs = {
    # inherit (inputs.gamindustri-utils.legacyPackages.x86_64-linux.default) lib;
    inherit inputs flake-config;
  };

  repositories = {
    inherit (inputs) nur unstable stable master default;
  };
}
