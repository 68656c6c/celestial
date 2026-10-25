export def deploy [message: string] {
  let repo_dir = $"($env.HOME)/.dotfiles"
  cd $repo_dir

  print "Formatting Nix files..."
  nix fmt

  print "Linting Nix files..."
  nix flake check

  print "Staging and committing..."
  git add .
  git commit -m $message

  print "Pushing..."
  git push

  print "Switching..."
  nh os switch

  print "Pushing to attic..."
  attic push celestial /run/current-system

  print "Done."
}
