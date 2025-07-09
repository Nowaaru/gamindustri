flakeParams @ {inputs, ...}: rec {
  packages.readonly.enable = true;

  system = {
    file = ./default.nix;
    usersDir = inputs.gamindustri-residents.outPath;

    description = "The primary workstation for Noire.";
    architecture = "x86_64-linux";
  };

  repositories = {
    main = inputs.gamindustri-utils.legacyPackages.${system.architecture}.default;
    fallback = {
      inherit (inputs.gamindustri-utils.legacyPackages.${system.architecture}) nur unstable stable master default;
    };
  };
}
