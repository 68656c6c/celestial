#!/usr/bin/env nu

# Staging a conflicted file would mark it resolved, markers and all.
def stop-on-conflicts [] {
  if (git ls-files --unmerged | is-not-empty) {
    error make --unspanned { msg: "unresolved conflicts: fix them, git add, then deploy again" }
  }
}

export def deploy [message: string] {
  let repo_dir = $"($env.HOME)/.dotfiles"
  # deploy-rs is also called `deploy`: outside the repo this is not meant.
  if not (($env.PWD == $repo_dir) or ($env.PWD | str starts-with $"($repo_dir)/")) {
    error make --unspanned { msg: $"deploy runs from ($repo_dir); deploy-rs is ^deploy" }
  }
  cd $repo_dir

  if ($"($repo_dir)/.git/rebase-merge" | path exists) {
    error make --unspanned { msg: "a rebase is in progress: git rebase --continue or --abort, then deploy again" }
  }
  if (git branch --show-current | str trim) != "main" {
    error make --unspanned { msg: "not on main" }
  }
  stop-on-conflicts

  # A flake only sees files git knows about. Staged in full: a pull cannot
  # stash a file that is only marked intent-to-add.
  git add .

  # On top of origin before anything is built. A switch from a checkout that
  # is behind takes back what the update pull requests and the other machines
  # brought, and the push after it is refused.
  print "Fetching..."
  git pull --rebase --autostash
  # an autostash that does not apply still exits 0
  stop-on-conflicts

  print "Formatting Nix files..."
  nix fmt

  # Only the lint: a full flake check evaluates every host, minutes on a
  # laptop. CI runs it on the push.
  print "Linting Nix files..."
  nix build --no-link .#checks.x86_64-linux.lint

  print "Staging..."
  git add .
  # main is public: a private key that strayed into the tree stops here
  let keys = (git diff --cached --name-only -G "AGE-SECRET-KEY-1" | lines)
  if ($keys | is-not-empty) {
    error make --unspanned { msg: $"an age secret key is staged: ($keys | str join ', ')" }
  }
  git status --short

  # Switch before the commit, so what reaches main has built and activated
  # here. A failed switch stops the deploy with nothing committed.
  print "Switching..."
  nh os switch

  print "Committing and pushing..."
  if (git diff --cached --quiet | complete).exit_code != 0 {
    git commit -m $message
  }
  git push

  print "Done. The other machines take it once CI has built it."
}

# Put this machine, or another one over tailscale ssh, on what CI built for
# main, now. Also over a generation made by hand.
export def upgrade [host?: string] {
  let unit = "celestial-upgrade-now.service"
  let started = if $host == null {
    systemctl start $unit | complete
  } else {
    ssh $host systemctl start $unit | complete
  }
  if $host == null {
    journalctl --unit $unit -I --output cat --no-pager
  } else {
    ssh $host journalctl --unit $unit -I --output cat --no-pager
  }
  if $started.exit_code != 0 {
    error make --unspanned { msg: "not upgraded" }
  }
}

# nu scripts/deploy.nu "message", for a shell that has not loaded the command
def main [message: string] {
  deploy $message
}
