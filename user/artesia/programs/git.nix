{
  programs.git = {
    enable = true;
    settings = {
      init = {
        defaultBranch = "main";
      };
      alias = {
        a = "add";
        c = "commit";
        pl = "pull";
        ph = "push";
      };
    };
  };
}
