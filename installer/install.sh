# Installs one host of this flake on the machine it boots on. Runs from the
# installer image on tty1. Every question comes before the disk is touched,
# after the countdown it runs by itself.
#   0. a reinstall: take the age key and wifi profiles from the install on
#      the disk (asks for its passphrase if that one is encrypted)
#   1. network: ethernet, wifi profiles from the stick, or the nmtui menu
#   2. the repo: celestial.bundle on the stick, otherwise a fresh clone
#   3. host: matched by DMI product name, else named by the only key on the
#      stick when that is for a host not in the repo yet, else asked. A name
#      without a folder becomes a new host, described from this hardware
#   4. scripts/setup-host.sh: hardware file, age key (keys/<host>.key from
#      the stick, otherwise new), and a login password when that key cannot
#      read the secrets yet
#   5. show the disk, 15 seconds to abort, disko
#   6. nixos-install, leave the repo in ~/.dotfiles, reboot
#
# The stick is any filesystem labelled CEL_KEYS, all of it optional:
#   keys/<host>.key      age key for that host (scripts/key-stick.sh)
#   keys/<host>.luks     disk passphrase, for a host with host.disk.encrypt
#   wifi/*.nmconnection  NetworkManager profiles, for machines without ethernet
#   attic.netrc          pull token for the private cache
#   celestial.bundle     `git bundle create celestial.bundle HEAD main`, to install
#                        commits that are not pushed

repo_url="${1:?repo url}"
repo=/tmp/celestial
stick=/run/celestial/stick
keys=/run/celestial/sops-nix
keys_label=CEL_KEYS

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }
shell() { say "dropping to a shell, celestial-install $repo_url starts over"; exec bash -l; }

mkdir -p "$stick" "$keys"
chmod 700 "$keys"

# Everything on screen also goes to a log, and a failing step stays on screen
# until enter: the service hands tty1 to a login prompt afterwards, which
# would wipe the one line that says what went wrong.
log=/run/celestial/install.log
term="$(tty 2>/dev/null || echo /dev/tty1)"
exec > >(tee -a "$log") 2>&1
# shellcheck disable=SC2154  # rc is set inside the trap
trap 'rc=$?; trap - ERR; printf "\n!! failed with exit %s at line %s: %s\n   log: %s\n" "$rc" "$LINENO" "$BASH_COMMAND" "$log"; read -r -p "enter for a shell " _ || true' ERR
if [ -e "/dev/disk/by-label/$keys_label" ] && ! mountpoint -q "$stick"; then
  mount -o ro "/dev/disk/by-label/$keys_label" "$stick"
  say "found the $keys_label stick"
fi


# 0. A reinstall: the install that is about to be wiped still holds the host's
#    age key and the wifi it knew. Take both along, so one stick is enough.
old=/run/celestial/old
old_host=""
old_root=/dev/disk/by-partlabel/disk-main-root
mkdir -p "$old" /run/celestial/old-keys
if [ -e "$old_root" ]; then
  old_dev="$old_root"
  if cryptsetup isLuks "$old_root" 2>/dev/null; then
    old_dev=""
    say "an encrypted install is on this disk"
    echo "Its disk passphrase lets the reinstall keep its key and wifi. Empty skips that."
    while read -r -s -p "    disk passphrase of the existing install: " old_pass && [ -n "$old_pass" ]; do
      echo
      if printf '%s' "$old_pass" | cryptsetup open --readonly --key-file - "$old_root" celestial-old; then
        old_dev=/dev/mapper/celestial-old
        break
      fi
      echo "    that did not open it, try again or leave empty"
    done
    echo
    unset old_pass
  fi
  if [ -n "$old_dev" ] && mount -o ro "$old_dev" "$old" 2>/dev/null; then
    old_host="$(readlink "$old/nix/var/nix/profiles/system" 2>/dev/null \
      | xargs -r -I{} readlink "$old/nix/var/nix/profiles/{}" 2>/dev/null \
      | sed -n 's/.*-nixos-system-\(.*\)-[0-9][0-9]\.[0-9][0-9].*/\1/p' || true)"
    if [ -n "$old_host" ] && [ -s "$old/var/lib/sops-nix/key" ]; then
      cp -a "$old/var/lib/sops-nix/." /run/celestial/old-keys/
      say "found an install of $old_host on this disk, its age key is kept if this becomes $old_host again"
    fi
    for profile in "$old"/.rw-etc/upper/NetworkManager/system-connections/*.nmconnection \
      "$old"/etc/NetworkManager/system-connections/*.nmconnection; do
      [ -e "$profile" ] || continue
      install -m 600 "$profile" /etc/NetworkManager/system-connections/
      echo "wifi profile from the existing install: $(basename "$profile")"
    done
    nmcli connection reload || true
    umount "$old"
  fi
  if [ -e /dev/mapper/celestial-old ]; then cryptsetup close celestial-old; fi
fi

# 1. network
for profile in "$stick"/wifi/*.nmconnection; do
  [ -e "$profile" ] || continue
  install -m 600 "$profile" /etc/NetworkManager/system-connections/
  nmcli connection reload || true
  echo "wifi profile from the stick: $(basename "$profile")"
done
online() { curl -fsS -m 10 -o /dev/null https://cache.nixos.org/nix-cache-info 2>/dev/null; }
tries=0
until online; do
  tries=$((tries + 1))
  if [ "$tries" -lt 4 ]; then
    echo "waiting for network..."
    sleep 5
    continue
  fi
  tries=0
  echo "no network yet. Plug in ethernet, or press enter to pick a wifi network."
  # shellcheck disable=SC2094  # a terminal, not a file
  if read -r -t 30; then nmtui connect < "$term" > "$term" 2>&1 || true; fi
done

# 2. repo
rm -rf "$repo"
if [ -f "$stick/celestial.bundle" ]; then
  say "configuration from celestial.bundle on the stick"
  git clone -q "$stick/celestial.bundle" "$repo"
  git -C "$repo" remote set-url origin "$repo_url"
else
  say "cloning $repo_url"
  git clone -q "$repo_url" "$repo"
fi
git -C "$repo" log -1 --format='at %h %s (%cr)'

# 3. host
say "reading the hosts (fetches the flake inputs first, give it a minute)"
nix eval --json "$repo#lib.hostFacts" > /run/celestial/hosts.json
product="$(sed 's/[[:space:]]*$//' /sys/class/dmi/id/product_name 2>/dev/null || true)"
host="$(jq -r --arg p "$product" 'to_entries[] | select(.value.dmi | index($p)) | .key' /run/celestial/hosts.json | head -1)"
# An unknown machine, and the stick holds exactly one key, for a host that has
# no folder yet: that key was made for this machine (key-stick.sh <stick> <name>)
new_from_stick=0
if [ -z "$host" ]; then
  mapfile -t stick_keys < <(find "$stick/keys" -maxdepth 1 -name '*.key' 2>/dev/null)
  if [ "${#stick_keys[@]}" = 1 ]; then
    candidate="$(basename "${stick_keys[0]}" .key)"
    if [[ "$candidate" =~ ^[a-z][a-z0-9-]*$ ]] && ! jq -e --arg h "$candidate" 'has($h)' /run/celestial/hosts.json >/dev/null; then
      host="$candidate"
      new_from_stick=1
    fi
  fi
fi
if [ "$new_from_stick" = 1 ]; then
  say "new host $host for this machine ($product), named by the key on the stick"
elif [ -n "$host" ]; then
  say "this machine is $host ($product)"
else
  say "no host claims this machine (DMI product: '${product:-unknown}')"
  echo "hosts: $(jq -r 'keys | join(" ")' /run/celestial/hosts.json)"
  echo "One of these names installs that host here. A new name creates a host for this machine."
  read -r -p "hostname, empty for a shell: " host
  [ -n "$host" ] || shell
  [[ "$host" =~ ^[a-z][a-z0-9-]*$ ]] || die "not a hostname: $host"
  if jq -e --arg h "$host" 'has($h)' /run/celestial/hosts.json >/dev/null; then
    echo "to have $host recognised next time: host.dmi = [ \"$product\" ];"
  fi
fi

# 4. hardware file, key, password, per-host folder
if [ -f "$stick/keys/$host.key" ]; then
  install -m 600 "$stick/keys/$host.key" "$keys/key"
  say "age key for $host taken from the stick"
elif [ "$old_host" = "$host" ] && [ -s /run/celestial/old-keys/key ]; then
  cp -a /run/celestial/old-keys/. "$keys/"
  say "age key for $host kept from the install on this disk"
fi
KEY_DIR="$keys" "$repo/scripts/setup-host.sh" "$host"
git -C "$repo" add -A

nix eval --json "$repo#lib.hostFacts.$host" > /run/celestial/host.json
layout="$(jq -r .disk.layout /run/celestial/host.json)"
swap_size="$(jq -r '.disk.swapSize // "none"' /run/celestial/host.json)"
esp_size="$(jq -r .disk.espSize /run/celestial/host.json)"
encrypt="$(jq -r .disk.encrypt /run/celestial/host.json)"
secureboot="$(jq -r .secureboot /run/celestial/host.json)"

# An encrypted disk needs its recovery passphrase now. The TPM takes over the
# daily unlocking later (scripts/secure-host.sh), this one is for the first
# boots and for the day the TPM refuses.
luks_args=()
if [ "$encrypt" = true ]; then
  if [ -f "$stick/keys/$host.luks" ]; then
    tr -d '\r\n' < "$stick/keys/$host.luks" > /run/celestial/luks
    say "disk passphrase for $host taken from the stick"
  else
    say "$host has an encrypted disk. Choose its recovery passphrase and keep it somewhere safe."
    while :; do
      read -r -s -p "    disk passphrase: " first; echo
      read -r -s -p "    once more: " second; echo
      if [ -n "$first" ] && [ "$first" = "$second" ]; then break; fi
      echo "    empty or not the same, try again"
    done
    printf '%s' "$first" > /run/celestial/luks
    unset first second
  fi
  chmod 600 /run/celestial/luks
  luks_args=(--arg encrypt true --argstr passwordFile /run/celestial/luks)
fi

# 5. disk: largest internal disk. Not the installer medium, nothing on USB.
iso_part="$(findmnt -no SOURCE /iso 2>/dev/null || true)"
iso_disk="$([ -n "$iso_part" ] && lsblk -no PKNAME "$iso_part" 2>/dev/null || true)"
disk="$(lsblk -dbno NAME,SIZE,RM,TYPE,TRAN \
  | awk -v skip="$iso_disk" '$4 == "disk" && $3 == 0 && $5 != "usb" && $1 != skip && $1 !~ /^zram/ { print $2, $1 }' \
  | sort -rn | head -1 | awk '{ print $2 }')"
[ -n "$disk" ] || die "no internal disk found"
device="/dev/$disk"

swap_args=(--arg swapSize null)
[ "$swap_size" = none ] || swap_args=(--argstr swapSize "$swap_size")
say "installing $host ($layout, encrypted: $encrypt, swap $swap_size, ESP $esp_size) onto $device"
echo "EVERYTHING ON $device WILL BE ERASED:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$device"
echo
for i in $(seq 15 -1 1); do
  printf '\rstarting in %2ds, press any key to abort ' "$i"
  if read -r -s -t 1 -n 1; then echo; say "aborted"; shell; fi
done
echo

say "partitioning $device"
disko --mode destroy,format,mount --yes-wipe-all-disks \
  --argstr device "$device" --argstr layout "$layout" \
  "${swap_args[@]}" --argstr espSize "$esp_size" "${luks_args[@]}" \
  "$repo/disko/layout.nix"
rm -f /run/celestial/luks

install -d -m 700 /mnt/var/lib/sops-nix
cp -a "$keys/." /mnt/var/lib/sops-nix/
# Secure Boot keys of this machine, so the boot files are signed from the
# first install on. The firmware gets them later, scripts/secure-host.sh.
if [ "$secureboot" = true ]; then
  say "creating Secure Boot keys"
  sbctl create-keys
  install -d -m 700 /mnt/var/lib/sbctl
  cp -a /var/lib/sbctl/. /mnt/var/lib/sbctl/
fi
cache_args=()
if [ -f "$stick/attic.netrc" ]; then
  install -m 600 "$stick/attic.netrc" /etc/nix/netrc
  systemctl restart nix-daemon
  cache_args=(--option extra-substituters https://attic.artesia.cloud/celestial)
  say "attic pull token taken from the stick"
fi

# 6. install
say "installing $host"
nixos-install --flake "$repo#$host" --no-root-passwd --no-channel-copy "${cache_args[@]}"

# The repo goes along, with whatever setup-host.sh wrote, ready to commit.
# artesia is the first normal user, so 1000:users.
install -d -m 700 -o 1000 -g 100 /mnt/home/artesia
cp -a "$repo" /mnt/home/artesia/.dotfiles
chown -R 1000:100 /mnt/home/artesia/.dotfiles

say "done"
echo "host:  $host"
echo "disk:  $device"
if [ "$secureboot" = true ] || [ "$encrypt" = true ]; then
  echo
  echo "Secure Boot and the TPM unlock are finished from the new system:"
  echo "  scripts/secure-host.sh in the repo (says what the next step is, run it after each reboot)"
fi
if [ -n "$(git -C "$repo" status --porcelain)" ]; then
  echo
  echo "The repo in the new home (.dotfiles) has changes to commit and push:"
  git -C "$repo" status --short
fi
if ! grep -q "$(age-keygen -y "$keys/key")" "$repo/secrets/secrets.yaml"; then
  echo
  echo "Login is the password you typed. To move it to the secrets, after that push:"
  echo "  on an enrolled machine:  git pull && scripts/rekey.sh, commit, push"
  echo "  on $host:                git pull && nh os switch"
fi
echo
mountpoint -q "$stick" && umount "$stick"
read -r -t 60 -p "rebooting in 60s, enter reboots now, ctrl-c for a shell " || true
reboot
