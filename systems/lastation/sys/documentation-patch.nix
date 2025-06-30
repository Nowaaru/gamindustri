{
    documentation = {
        enable = true;
        nixos.enable = true;
        doc.enable = true;
        dev.enable = true;
        info.enable = true;
        man = {
            enable = true;
            generateCaches = true;
            man-db = {
                enable = true;
            };
        };
    };
}
