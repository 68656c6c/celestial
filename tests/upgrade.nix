# host.upgrade against a local git repository standing in for main. The
# systems it is offered are more nodes that are never started: built
# beforehand and already in the machine's store, the way a cache would
# deliver them.
{ module }:

let
  base =
    { lib, pkgs, ... }:
    {
      imports = [ module ];

      networking.hostName = "machine";
      host.upgrade = {
        enable = true;
        repo = "file:///srv/repo";
        cache = "http://localhost:8080";
      };

      boot.loader.grub.enable = false;
      system.switch.enable = true;
      security.polkit.enable = true;
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = lib.mkForce [ ];
      };

      users.users.alice = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      users.users.bob.isNormalUser = true;
      environment.systemPackages = [
        pkgs.gitMinimal
        pkgs.darkhttpd
      ];
    };
in

{
  name = "celestial-upgrade";

  nodes.machine =
    { nodes, ... }:
    {
      imports = [ base ];
      virtualisation.memorySize = 2048;
      virtualisation.additionalPaths = [
        nodes.next.system.build.toplevel
        nodes.later.system.build.toplevel
        nodes.unbootable.system.build.toplevel
      ];
    };

  nodes.next = {
    imports = [ base ];
    environment.etc.generation.text = "next";
  };

  nodes.later = {
    imports = [ base ];
    environment.etc.generation.text = "later";
  };

  nodes.unbootable =
    { lib, pkgs, ... }:
    {
      imports = [ base ];
      system.build.installBootLoader = lib.mkForce "${pkgs.coreutils}/bin/false";
    };

  testScript =
    { nodes, ... }:
    ''
      next = "${nodes.next.system.build.toplevel}"
      later = "${nodes.later.system.build.toplevel}"
      unbootable = "${nodes.unbootable.system.build.toplevel}"
      missing = "/nix/store/" + "a" * 32 + "-nixos-system-machine-1"
      state = "/var/lib/celestial-upgrade"

      def main_is(out):
          machine.succeed(
              "printf '%s\\n' '{ outputs = _: { nixosConfigurations.machine.config.system.build.toplevel.outPath = \"" + out + "\"; }; }' > /srv/repo/flake.nix",
              "git -C /srv/repo add flake.nix",
              "git -C /srv/repo commit -qm main",
          )

      def profile():
          return machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()

      def auto(ok=True):
          run = machine.succeed if ok else machine.fail
          machine.succeed("systemctl reset-failed celestial-upgrade.service || true")
          run("systemctl start celestial-upgrade.service")
          return machine.succeed("journalctl -u celestial-upgrade.service -I --output cat")

      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.succeed(
          "git init -q -b main /srv/repo",
          "git -C /srv/repo config user.name test",
          "git -C /srv/repo config user.email test@example.org",
          "nix-env -p /nix/var/nix/profiles/system --set /run/current-system",
          "mkdir -p /srv/cache",
          "systemd-run --unit=cache darkhttpd /srv/cache --port 8080",
      )
      machine.wait_for_open_port(8080)
      booted = profile()

      with subtest("the timer is there"):
          machine.succeed("systemctl is-active celestial-upgrade.timer")

      with subtest("a generation made by hand is left alone"):
          main_is(next)
          assert "made by hand" in auto()
          assert profile() == booted

      with subtest("a second run does not evaluate again"):
          assert "evaluating" not in auto()
          assert profile() == booted

      with subtest("upgrade takes main over it, wheel needs no password"):
          machine.fail("su bob -c 'systemctl start celestial-upgrade-now.service'")
          assert profile() == booted
          machine.succeed("su alice -c 'systemctl start celestial-upgrade-now.service'")
          assert profile() == next

      with subtest("a followed generation moves with main"):
          main_is(later)
          assert "now on main" in auto()
          assert profile() == later

      with subtest("what the cache does not have is not taken, and nothing is built"):
          main_is(missing)
          assert "not in the cache yet" in auto()
          machine.succeed(f"test -e {state}/unbuilt")
          assert profile() == later
          machine.fail("systemctl start celestial-upgrade-now.service")
          assert profile() == later

      with subtest("a cache that is out of reach is not taken for a missing build"):
          machine.succeed(f"rm {state}/unbuilt", "systemctl stop cache")
          assert "does not answer" in auto()
          machine.fail(f"test -e {state}/unbuilt")
          machine.succeed("systemd-run --unit=cache darkhttpd /srv/cache --port 8080")
          machine.wait_for_open_port(8080)

      with subtest("another host's system is refused"):
          main_is(next.replace("nixos-system-machine", "nixos-system-other"))
          auto(ok=False)
          assert profile() == later

      with subtest("an install that failed halfway is done again, not taken for done"):
          main_is(unbootable)
          auto(ok=False)
          assert profile() == unbootable
          machine.succeed(f"test -e {state}/pending")
          assert "already on main" not in auto(ok=False)
          main_is(next)
          assert "now on main" in auto()
          machine.fail(f"test -e {state}/pending")
          assert profile() == next

      with subtest("a rollback by hand stays"):
          machine.succeed("nix-env -p /nix/var/nix/profiles/system --set " + booted)
          main_is(later)
          assert "made by hand" in auto()
          assert profile() == booted

      with subtest("a machine switched by hand to exactly main is adopted"):
          main_is(booted)
          assert "already on main" in auto()
          main_is(next)
          assert "now on main" in auto()
          assert profile() == next
    '';
}
