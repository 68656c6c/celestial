{ ... }:

{
  xdg.configFile."git/allowed_signers".text = ''
    git.tlnxs@dralias.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ2pbnWqUAWbX+354ZDWWxKnR61RI/BaRpnkeevv1wEL
  '';

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
      # Clones over https (the installer's ~/.dotfiles, anything pasted from a
      # browser) fetch without a login and push over ssh, where the key is.
      url."git@github.com:".pushInsteadOf = "https://github.com/";
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
      commit.gpgsign = true;
      user = {
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ2pbnWqUAWbX+354ZDWWxKnR61RI/BaRpnkeevv1wEL";
        name = "68656c6c";
        email = "git.tlnxs@dralias.com";
      };
    };
  };
}
