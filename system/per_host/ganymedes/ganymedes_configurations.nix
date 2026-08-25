{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "ganymedes";
  security = {
  tpm2.enable = false;
  };
}
