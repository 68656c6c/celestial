# Unattended install of one host of this flake. Runs from the installer image.
#   1. match the machine to a host by DMI product name (or ask)
#   2. pick the internal disk, show it, give 15 seconds to abort
#   3. wait for network (caches, flake inputs)
#   4. disko: wipe, partition, format, mount
#   5. age key: from a stick labelled CELESTIAL_KEYS (keys/<host>.key) or new
#   6. nixos-install, set a password if the key is new, reboot

hosts_json="${1:?hosts json}"
flake=/etc/celestial
keys_label=CELESTIAL_KEYS

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }
shell() { say "dropping to a shell"; exec bash -l; }

# 1. host
product="$(sed 's/[[:space:]]*$//' /sys/class/dmi/id/product_name 2>/dev/null || true)"
host="$(jq -r --arg p "$product" 'to_entries[] | select(.value.dmi | index($p)) | .key' "$hosts_json" | head -1)"
if [ -z "$host" ]; then
  say "no host matches this machine (DMI product: '${product:-unknown}')"
  echo "known hosts: $(jq -r 'keys | join(" ")' "$hosts_json")"
  read -r -p "hostname to install, empty for a shell: " host
  [ -n "$host" ] || shell
  jq -e --arg h "$host" 'has($h)' "$hosts_json" >/dev/null || die "unknown host $host"
fi
layout="$(jq -r --arg h "$host" '.[$h].layout' "$hosts_json")"
swap_size="$(jq -r --arg h "$host" '.[$h].swapSize' "$hosts_json")"
esp_size="$(jq -r --arg h "$host" '.[$h].espSize' "$hosts_json")"

# 2. disk: largest non-removable disk that is not the installer medium
iso_part="$(findmnt -no SOURCE /iso 2>/dev/null || true)"
iso_disk="$([ -n "$iso_part" ] && lsblk -no PKNAME "$iso_part" 2>/dev/null || true)"
disk="$(lsblk -dbno NAME,SIZE,RM,TYPE \
  | awk -v skip="$iso_disk" '$4 == "disk" && $3 == 0 && $1 != skip { print $2, $1 }' \
  | sort -rn | head -1 | awk '{ print $2 }')"
[ -n "$disk" ] || die "no internal disk found"
device="/dev/$disk"

say "installing $host ($layout, swap $swap_size, ESP $esp_size) onto $device"
echo "EVERYTHING ON $device WILL BE ERASED:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$device"
echo
for i in $(seq 15 -1 1); do
  printf '\rstarting in %2ds, press any key to abort ' "$i"
  if read -r -s -t 1 -n 1; then echo; say "aborted"; shell; fi
done
echo

# 3. network
until curl -fsS -o /dev/null https://cache.nixos.org/nix-cache-info; do
  echo "waiting for network, plug in ethernet..."
  sleep 5
done

# 4. disk
say "partitioning $device"
disko --mode destroy,format,mount --yes-wipe-all-disks \
  --argstr device "$device" --argstr layout "$layout" \
  --argstr swapSize "$swap_size" --argstr espSize "$esp_size" \
  "$flake/disko/layout.nix"

# 5. age key
install -d -m 700 /mnt/var/lib/sops-nix
key_from_stick=0
if [ -e "/dev/disk/by-label/$keys_label" ]; then
  mkdir -p /keys
  mount -o ro "/dev/disk/by-label/$keys_label" /keys
  if [ -f "/keys/keys/$host.key" ]; then
    cp "/keys/keys/$host.key" /mnt/var/lib/sops-nix/key
    key_from_stick=1
    say "age key taken from the $keys_label stick"
  fi
  umount /keys
fi
if [ ! -f /mnt/var/lib/sops-nix/key ]; then
  age-keygen -o /mnt/var/lib/sops-nix/key 2>/dev/null
  say "generated a new age key"
fi
chmod 600 /mnt/var/lib/sops-nix/key
pubkey="$(age-keygen -y /mnt/var/lib/sops-nix/key)"
echo "$pubkey" > /mnt/var/lib/sops-nix/key.pub

# 6. install
say "installing $host"
nixos-install --flake "$flake#$host" --no-root-passwd --no-channel-copy

if [ "$key_from_stick" = 0 ]; then
  say "this key is not in .sops.yaml yet, so the login password cannot come from secrets.yaml"
  echo "set one for artesia now (replaced by the secret once the key is added):"
  until nixos-enter --root /mnt -c 'passwd artesia'; do echo "try again"; done
fi

say "done"
cat <<MSG
host:            $host
disk:            $device
age public key:  $pubkey

Add the key to .sops.yaml under keys and all, then: sops updatekeys secrets/secrets.yaml
MSG
read -r -t 30 -p "rebooting in 30s, enter reboots now, ctrl-c for a shell " || true
reboot
