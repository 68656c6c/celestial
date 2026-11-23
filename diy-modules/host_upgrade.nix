{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.host.upgrade;

  upgrade = pkgs.writeShellApplication {
    name = "celestial-upgrade";
    runtimeInputs = [
      config.nix.package
      config.system.build.nixos-rebuild
      config.systemd.package
      pkgs.coreutils
      pkgs.curl
      pkgs.findutils
      pkgs.gitMinimal
      pkgs.libnotify
      pkgs.util-linux
    ];
    text = ''
      mode="''${1:-auto}"
      host=${lib.escapeShellArg config.networking.hostName}
      repo=${lib.escapeShellArg cfg.repo}
      cache=${lib.escapeShellArg cfg.cache}
      state="''${STATE_DIRECTORY:-/var/lib/celestial-upgrade}"

      exec 9> "$state/lock"
      if ! flock -n 9; then
        echo "an upgrade is already running"
        [ "$mode" = auto ] && exit 0
        exit 1
      fi

      # fails when nobody was there to be told
      notify() {
        local sent=1
        for bus in /run/user/*/bus; do
          [ -e "$bus" ] || continue
          uid="''${bus#/run/user/}"
          uid="''${uid%/bus}"
          [ "$uid" -ge 1000 ] || continue
          if runuser -u "$(id -nu "$uid")" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus" \
            notify-send -a celestial "$1" "$2"; then
            sent=0
          fi
        done
        return "$sent"
      }

      # once per commit on main, not once per timer run
      notify_once() {
        [ -e "$state/told" ] && return 0
        if notify "$1" "$2"; then
          touch "$state/told"
        fi
      }

      stop() {
        echo "$1"
        [ "$mode" = auto ] && exit 0
        exit 1
      }

      # The timer often fires at boot, before the wifi is up.
      tries=1
      [ "$mode" = auto ] && tries=5
      rev=""
      for try in $(seq "$tries"); do
        rev="$(git ls-remote "$repo" refs/heads/main | cut -f1)" || rev=""
        [ -n "$rev" ] && break
        [ "$try" = "$tries" ] || sleep 60
      done
      [ -n "$rev" ] || stop "$repo does not answer, nothing done"
      short="''${rev:0:7}"

      main_rev="" main_out=""
      if [ -e "$state/main" ]; then
        read -r main_rev main_out < "$state/main" || true
      fi
      if [ "$rev" != "$main_rev" ]; then
        echo "main is at $short, evaluating $host"
        main_out="$(nix eval --raw "git+$repo?ref=main&rev=$rev#nixosConfigurations.$host.config.system.build.toplevel.outPath")"
        case "$main_out" in
          /nix/store/*-nixos-system-"$host"-*) ;;
          *) echo "not a system for $host: $main_out" >&2; exit 1 ;;
        esac
        printf '%s %s\n' "$rev" "$main_out" > "$state/main"
        rm -f "$state/told"
      fi

      current="$(readlink -f /nix/var/nix/profiles/system)"
      # nixos-rebuild sets the profile before it installs the boot entry: a
      # run that died in between left `pending` and is done again.
      if [ "$main_out" = "$current" ] && [ ! -e "$state/pending" ]; then
        echo "already on main ($short)"
        printf '%s\n' "$current" > "$state/followed"
        rm -f "$state/unbuilt"
        exit 0
      fi

      # A generation somebody switched to by hand, a rollback included, stays
      # until main matches it or `upgrade` is run.
      followed=""
      [ -e "$state/followed" ] && followed="$(cat "$state/followed")"
      if [ "$mode" = auto ] && [ "$current" != "$followed" ] && [ ! -e "$state/pending" ]; then
        echo "the running generation was made by hand and is not main, leaving it"
        notify_once "Not following main" "This machine runs a generation made by hand. main is at $short; deploy, or run upgrade to take it."
        exit 0
      fi

      # A store path, not a derivation: this can only download. What CI has
      # not built and pushed is not there, and nothing is compiled here. No
      # negative cache: `upgrade` right after CI finished must see the result.
      if ! nix-store --realise --option narinfo-cache-negative-ttl 0 \
        --add-root "$state/system" "$main_out" > /dev/null; then
        hash="''${main_out#/nix/store/}"
        hash="''${hash%%-*}"
        code="$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "$cache/$hash.narinfo")" || code=000
        case "$code" in
          404)
            # counted from the first miss, not from the newest commit: a red
            # CI with a push every day must still be reported
            [ -e "$state/unbuilt" ] || touch "$state/unbuilt"
            if [ -n "$(find "$state/unbuilt" -mmin +1200)" ]; then
              notify_once "main is not built" "The cache has had no system for $host since yesterday, main is at $short. Look at the build-hosts runs on GitHub."
            fi
            stop "main ($short) is not in the cache yet"
            ;;
          200) stop "main ($short) is in the cache but could not be downloaded" ;;
          *) stop "the cache does not answer, is Pangolin connected? Nothing done" ;;
        esac
      fi
      rm -f "$state/unbuilt"

      # without --no-reexec it first builds nixos-rebuild from a channel this
      # flake-only machine does not have
      touch "$state/pending"
      if ! nixos-rebuild ${cfg.operation} --no-reexec --store-path "$main_out"; then
        notify "System update failed" "main ($short) was downloaded but not installed. journalctl -u celestial-upgrade" || true
        exit 1
      fi
      rm -f "$state/pending"
      printf '%s\n' "$main_out" > "$state/followed"
      echo "now on main ($short)"
      notify "System updated to main" ${
        lib.escapeShellArg (
          if cfg.operation == "boot" then
            "The new generation starts at the next boot."
          else
            "The new generation is running."
        )
      } || true
    '';
  };

  unit = mode: {
    description = "Follow main: take the system CI built for this host";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # a switch must not stop the upgrade that is running it
    restartIfChanged = false;
    unitConfig.X-StopOnRemoval = false;
    environment = config.nix.envVars // {
      HOME = "/root";
    };
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "celestial-upgrade";
      ExecStart = "${lib.getExe upgrade} ${mode}";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
in

{
  options.host.upgrade = {
    enable = lib.mkEnableOption "following main: twice a day, download the system CI built for this host from the newest commit on main and make it the boot default. Never compiles, never touches a generation made by hand";

    operation = lib.mkOption {
      type = lib.types.enum [
        "boot"
        "switch"
      ];
      default = "boot";
      description = "boot: the new generation starts at the next boot. switch: it is activated right away, under whatever is running.";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/68656c6c/celestial";
      description = "Git repository whose main branch this host follows.";
    };

    cache = lib.mkOption {
      type = lib.types.str;
      default = "https://attic.cl2.artesia.cloud/celestial";
      description = "The cache CI pushes to. Asked when a download fails, to tell a system that is not built from a cache that is out of reach.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.celestial-upgrade = unit "auto";
    # `upgrade` in nushell: the same, now, and over a generation made by hand
    systemd.services.celestial-upgrade-now = unit "now";

    # Not behind the mains gate of host.laptop: with nothing new this is one
    # git request. The second slot is for a machine that was off at midnight:
    # the missed run fires at boot, before a login has brought Pangolin up.
    systemd.timers.celestial-upgrade = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = [
          "daily"
          "*-*-* 13:00"
        ];
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units"
            && action.lookup("unit") == "celestial-upgrade-now.service"
            && action.lookup("verb") == "start"
            && subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
