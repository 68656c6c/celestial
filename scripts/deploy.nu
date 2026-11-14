export def deploy [message: string] {
  let repo_dir = $"($env.HOME)/.dotfiles"
  cd $repo_dir

  print "Formatting Nix files..."
  nix fmt

  print "Linting Nix files..."
  nix flake check

  # Staged first: a flake only sees files git knows about.
  print "Staging..."
  git add .

  # Switch before the commit, so what reaches main has built and activated
  # here. A failed switch stops the deploy with nothing committed.
  print "Switching..."
  nh os switch

  print "Committing and pushing..."
  git commit -m $message
  git push

  print "Done."
}
