export def cache-slow [] {
  if (sys host | get hostname) != "io" { return }
  print "Pushing the slow packages to the caches..."
  try {
    with-env { SLOW_ONLY: "1" } { ^$"($env.HOME)/.dotfiles/scripts/build-hosts.sh" }
  } catch {
    print "Cache push failed, carrying on."
  }
}

export def deploy [message: string] {
  let repo_dir = $"($env.HOME)/.dotfiles"
  cd $repo_dir

  # A flake only sees files git knows about, so new files are made known
  # before anything looks at the tree.
  git add --intent-to-add .

  print "Formatting Nix files..."
  nix fmt

  # Only the lint: a full flake check evaluates every host, minutes on a
  # laptop. CI runs it on the push.
  print "Linting Nix files..."
  nix build --no-link .#checks.x86_64-linux.lint

  print "Staging..."
  git add .

  # Switch before the commit, so what reaches main has built and activated
  # here. A failed switch stops the deploy with nothing committed.
  print "Switching..."
  nh os switch
  cache-slow

  print "Committing and pushing..."
  git commit -m $message
  git push

  print "Done."
}

# nu scripts/deploy.nu "message", for a shell that has not loaded the command
def main [message: string] {
  deploy $message
}
