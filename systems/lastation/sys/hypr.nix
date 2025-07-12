{
  pkgs,
  inputs,
  meta,
  ...
}: {
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${meta.system.architecture}.hyprland;
    portalPackage = inputs.hyprland.packages.${meta.system.architecture}.xdg-desktop-portal-hyprland;
  };
}
