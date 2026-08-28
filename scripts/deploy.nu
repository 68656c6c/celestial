export def deploy [message: string] {
  let repo_dir = "/home/artesia/.dotfiles"
  cd $repo_dir

  print "Formatting Nix files..."
  nixfmt-all

  print "Staging and committing..."
  git add .
  git commit -m $message

  print "Pushing..."
  git push

  print "Switching..."
  nh os switch

  print "Done."
}
