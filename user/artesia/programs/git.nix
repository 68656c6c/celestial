{
  ...
}:

{
  programs.git = {
    enable = true;
    settings = {
      init = {
        defaultBranch = "main";
      };
      alias = {
        a = "add *";
        c = "commit -m";
        pl = "pull";
        ph = "push";
      };
      gpg.format = "ssh";
      commit.gpgsign = true;
      user = {
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ2pbnWqUAWbX+354ZDWWxKnR61RI/BaRpnkeevv1wEL";
        name = "68656c6c";
      };
    };
  };
}
