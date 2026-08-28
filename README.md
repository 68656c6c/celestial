# Celestial

My nixos stack that includes flake and home manager
Running hyprland/niri + noctalia

## folder structure
```
  diy-modules     - custom options
  diy-packages    - custom packages
  imports         - the global modules being imported
  overlays        - over..lays?
  scripts         - random scripts for the stack
  secrets         - why are you looking huh
  system          - the boilerplate and per-host stuff
  user            - mainly hm related stuff
```

## Adding a host
1. Install git and nh and pull the repo
2. Rename to .dotfiles in ~/
3. Delete /etc/nixos/configuration.nix
4. Run setup-host.sh <hostname>
5. nh os switch .#<hostname>
6. Enjoy :D

Anyone could honestly just clone and use this, but my secrets have no use and it is entirely vibes based on the structure so don't expect it to be amazing or whatever lol
