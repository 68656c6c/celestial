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
    };
  };
}
