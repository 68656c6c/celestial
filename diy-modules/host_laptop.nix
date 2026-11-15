{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.host.laptop;

  notify = pkgs.writeShellApplication {
    name = "on-ac-notify";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      util-linux
    ];
    text = ''
      for bus in /run/user/*/bus; do
        [ -e "$bus" ] || continue
        uid="''${bus#/run/user/}"
        uid="''${uid%/bus}"
        [ "$uid" -ge 1000 ] || continue
        runuser -u "$(id -nu "$uid")" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus" \
          notify-send -a celestial "$1" "$2" || true
      done
    '';
  };

  # Started by the timer in place of the job itself.
  gate = pkgs.writeShellApplication {
    name = "on-ac-gate";
    runtimeInputs = [
      config.systemd.package
      pkgs.coreutils
      notify
    ];
    text = ''
      unit="$1" label="$2"
      if systemd-ac-power; then
        rm -f "/var/lib/on-ac/$unit"
        exec systemctl start --no-block "$unit.service"
      fi
      printf '%s\n' "$label" > "/var/lib/on-ac/$unit"
      on-ac-notify "Waiting for mains power" "The $label starts when the charger is plugged in."
    '';
  };

  # The timer often fires at boot, before anyone is logged in to be told.
  waiting = pkgs.writeShellApplication {
    name = "on-ac-waiting";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = ''
      sleep 10
      for marker in /var/lib/on-ac/*; do
        [ -e "$marker" ] || continue
        notify-send -a celestial "Waiting for mains power" \
          "The $(cat "$marker") starts when the charger is plugged in." || true
      done
    '';
  };

  pending = pkgs.writeShellApplication {
    name = "on-ac-pending";
    runtimeInputs = [
      config.systemd.package
      pkgs.coreutils
      notify
    ];
    text = ''
      for marker in /var/lib/on-ac/*; do
        [ -e "$marker" ] || continue
        unit="$(basename "$marker")"
        label="$(cat "$marker")"
        rm -f "$marker"
        systemctl start --no-block "$unit.service"
        on-ac-notify "On mains power" "Starting the $label that was waiting."
      done
    '';
  };
in

{
  options.host.laptop = {
    enable = lib.mkEnableOption "laptop power management: tlp, zram and maintenance jobs that wait for mains power";

    thermald = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run thermald. Intel only, turn off on AMD machines.";
    };

    onAC = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        nix-gc = "nix store cleanup";
      };
      description = "Timer-driven services (unit name without .service, and a name for the notification) that only start on mains power. One whose timer fires on battery starts the moment the charger is plugged in. No effect on a host that is not a laptop.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tlp = {
      enable = true;
      # tlp-pd speaks the power-profiles-daemon D-Bus interface, so noctalia
      # and waybar keep their power profile widgets while tlp does the work.
      pd.enable = true;
    };
    services.power-profiles-daemon.enable = false;

    services.thermald.enable = cfg.thermald;

    zramSwap.enable = true;

    host.laptop.onAC = {
      nix-gc = "nix store cleanup";
      nix-optimise = "nix store optimisation";
    };

    # ConditionACPower on the job would skip the run and wait for the next
    # calendar slot. The timer starts a gate instead: on battery it leaves a
    # marker, and the udev rule picks that up when the charger comes back.
    systemd.timers = lib.mapAttrs (name: _: {
      timerConfig.Unit = "on-ac-${name}.service";
    }) cfg.onAC;

    systemd.services =
      lib.mapAttrs' (
        name: label:
        lib.nameValuePair "on-ac-${name}" {
          description = "Start the ${label} on mains power";
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "on-ac";
            ExecStart = "${lib.getExe gate} ${
              lib.escapeShellArgs [
                name
                label
              ]
            }";
          };
        }
      ) cfg.onAC
      // {
        on-ac-pending = {
          description = "Start what waited for mains power";
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionACPower = true;
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "on-ac";
            ExecStart = lib.getExe pending;
          };
        };
      };

    systemd.user.services.on-ac-waiting = {
      description = "Say what is waiting for mains power";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe waiting;
      };
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${config.systemd.package}/bin/systemctl start --no-block on-ac-pending.service"
    '';
  };
}
