{
  ...
}:

{
  networking.hostName = "aphrodite";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  host.monitors = [
    {
      output = "eDP-1";
      mode = "1920x1080";
      scale = 1.0;
    }
  ];

  host.cursor.size = 32;
  host.laptop = {
    enable = true;
    thermald = false; # AMD
  };
}
