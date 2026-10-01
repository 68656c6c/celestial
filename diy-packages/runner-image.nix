{
  lib,
  dockerTools,
  writeTextDir,
  nix,
  git,
  openssh,
  cacert,
  jq,
  nodejs,
  attic-client,
  bashInteractive,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gnutar,
  gzip,
  xz,
  curl,
  iana-etc,
  name ? "forgejo-runner-nix",
  tag ? "latest",
  atticCacheUrl ? "https://attic.artesia.cloud/celestial",
  atticPublicKey ? "celestial:Pu6qm2/CCY/lcC9FVyXRNGBuXa8QzAGOQzA9BSIx51g=",
}:

let
  buildUsers = lib.genList (i: i + 1) 16;

  nss = dockerTools.fakeNss.override {
    extraPasswdLines = map (
      i:
      "nixbld${toString i}:x:${toString (30000 + i)}:30000:Nix build user ${toString i}:/var/empty:/bin/sh"
    ) buildUsers;
    extraGroupLines = [
      "nixbld:x:30000:${lib.concatMapStringsSep "," (i: "nixbld${toString i}") buildUsers}"
    ];
  };

  nixConf = writeTextDir "etc/nix/nix.conf" ''
    experimental-features = nix-command flakes
    sandbox = false
    filter-syscalls = false
    build-users-group = nixbld
    trusted-users = root
    substituters = ${atticCacheUrl} https://cache.nixos.org/
    trusted-public-keys = ${atticPublicKey} cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    accept-flake-config = true
    warn-dirty = false
  '';
in
dockerTools.buildLayeredImageWithNixDb {
  inherit name tag;

  contents = [
    nixConf
    nss
    dockerTools.binSh
    dockerTools.usrBinEnv
    dockerTools.caCertificates
    nix
    git
    openssh
    cacert
    jq
    nodejs
    attic-client
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gnutar
    gzip
    xz
    curl
    iana-etc
  ];

  extraCommands = ''
    mkdir -p tmp var/tmp root/.ssh etc/ssh
    chmod 1777 tmp var/tmp
    chmod 700 root/.ssh
  '';

  config = {
    Cmd = [ "/bin/bash" ];
    WorkingDir = "/";
    Env = [
      "PATH=/bin:/usr/bin"
      "HOME=/root"
      "USER=root"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
      "NIX_PAGER=cat"
      "LANG=C.UTF-8"
    ];
  };
}
