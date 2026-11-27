{
  config,
  pkgs,
  ...
}:

let
  # Types the clipboard as keystrokes, for windows that take no paste (VM
  # consoles, noVNC, fields that block it). The argument is the wait in
  # seconds before typing: time to click into the window, or for a hotkey's
  # modifiers to be let go. ydotool sends US-layout keycodes.
  typeClipboard = pkgs.writeShellApplication {
    name = "type-clipboard";
    runtimeInputs = [
      pkgs.wl-clipboard
      pkgs.ydotool
    ];
    text = ''
      # set at login only: a session older than the switch, or a hotkey from a
      # compositor started without it, would look for a per-user socket
      export YDOTOOL_SOCKET="''${YDOTOOL_SOCKET:-${
        config.environment.variables.YDOTOOL_SOCKET or "/run/ydotoold/socket"
      }}"
      text="$(wl-paste -n)"
      sleep "''${1:-0.3}"
      ydotool type --key-delay 20 -- "$text"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    typeClipboard
    wl-clipboard
    exfatprogs
    dosfstools
    telegram-desktop
    qbittorrent
    obsidian
    mpv
    unzip
    btop # processes, cpu, memory
    ncdu # what is using the disk
    fastfetch # system summary in the terminal
    pciutils # lspci
    usbutils # lsusb
    p7zip
    anki-bin
    libreoffice-fresh
    vesktop
    gparted
    ntfs3g
    impression
    dig
    nmap
    nwg-look
    adw-gtk3
    rewaita
    morewaita-icon-theme
    hyprpicker
    glib
    networkmanagerapplet
    gpu-screen-recorder-gtk
    nh
    nixfmt
    helix # for root: sudo -E sops edit ... keeps EDITOR=hx, secure_path has no user profile
    fortune
    zenity
    cachix
    age
    sops
    nurl
    nushell
    xwayland-satellite
    brightnessctl
    playerctl
    bitwarden-desktop
    opencode
    opencode-claude-auth
    claude-code
    stremio-linux-shell
    attic-client
    qimgv
    pwvucontrol
    blanket # background noise
    wdisplays
    pangolin-cli
    pantheon.pantheon-agent-polkit
    diy.helium
    diy.zen-browser
    diy.sunnify
    qt6.qtwayland
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.kio-extras
    kdePackages.breeze-icons
    kdePackages.kwallet
    kdePackages.qtstyleplugin-kvantum
    kdePackages.qt6ct
  ];
}
