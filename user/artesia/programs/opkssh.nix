{
  programs.opkssh = {
    enable = true;
    settings = {
      default_provider = "kanidm";
      providers = [
        # Kanidm public client: PKCE, no secret
        {
          alias = "kanidm";
          issuer = "https://auth.artesia.cloud/oauth2/openid/opkssh";
          client_id = "opkssh";
          scopes = "openid email profile";
          redirect_uris = [
            "http://localhost:3000/login-callback"
            "http://localhost:10001/login-callback"
            "http://localhost:11110/login-callback"
          ];
        }
      ];
    };
  };
}
