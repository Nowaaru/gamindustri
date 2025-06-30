{self, inputs, lib, ...} @ args: {
  description = "The primary workstation for Noire.";
  systems = ["x86_64-linux"];

  specialArgs = {
    inherit inputs lib;
  };

  repositories = {
    inherit (inputs) nur unstable stable master default;
  };
}
