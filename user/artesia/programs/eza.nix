{ ... }:

{
  programs.eza = {
    enable = true;
    enableNushellIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--header"
      "--sort=type"
      "--hyperlink"
      "--level=3"
      "--time=created"
      "--time-style=long-iso"
    ];
  };
}
