{
  ...
}:

{
  networking.hostName = "ganymedes";
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

  host.laptop.enable = true;

  security = {
    tpm2.enable = false;
  };
}
