{ pkgs, ... }: {

    programs.nix-ld = with pkgs; {
        enable = true;
        package = nix-ld-rs;
        libraries = [
            # glfw3
            # gtk3
        ];
    };
}
