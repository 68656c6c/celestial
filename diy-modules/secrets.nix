{
  sops.secrets = {
    dc01_ca = {
      sopsFile = ../secrets/dc01_ca.pem;
      format = "binary";
    };
  };
}
