export def nixfmt-all [] {
  let repo_dir = "/home/artesia/.dotfiles"
  let files = (glob "**/*.nix"
    | where { not ($in =~ "result") and not ($in =~ ".git") and not ($in =~ "flake.lock") })

  for file in $files {
    print $"Formatting: ($file)"
    nixfmt $file
  }

  print "Done."
}
