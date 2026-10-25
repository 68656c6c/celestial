# Thin wrappers around the flake's own formatter and checks.
# `nix fmt` runs nixfmt over the tree, `nix flake check` runs deadnix, statix and nixfmt --check.

export def nixfmt-all [] {
  let repo_dir = $"($env.HOME)/.dotfiles"
  cd $repo_dir
  print "Formatting Nix files..."
  nix fmt
  print "Done."
}

export def deadnix-all [] {
  let repo_dir = $"($env.HOME)/.dotfiles"
  cd $repo_dir
  print "Linting Nix files..."
  nix flake check
  print "No lint findings."
}
