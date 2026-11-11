#!/usr/bin/env bash
# Finish Secure Boot and the TPM disk unlock on a host that has
# host.secureboot.enable and host.disk.encrypt. It looks at where the machine
# is and does, or names, the next step, so run it again after each reboot:
#
#   1. firmware in setup mode  ->  enrolls this machine's keys (and Microsoft's,
#                                  which the firmware's own option ROMs need)
#   2. Secure Boot on          ->  binds the disk to the TPM, sealed to the
#                                  Secure Boot state (PCR 7)
#
#   secure-host.sh --again     bind the TPM again, after a firmware update or
#                              new Secure Boot keys made the disk ask for the
#                              passphrase
set -euo pipefail

DISK=/dev/disk/by-partlabel/disk-main-root
again=0
[ "${1:-}" = "--again" ] && again=1

status="$(sudo sbctl status 2>&1 || true)"
echo "$status"
echo

if ! sudo test -d /var/lib/sbctl/keys; then
  echo "No Secure Boot keys in /var/lib/sbctl. Set host.secureboot.enable, then:"
  echo "  sudo sbctl create-keys && nh os switch"
  exit 1
fi

if ! grep -qiE "secure boot:.*enabled" <<<"$status"; then
  if grep -qiE "setup mode:.*enabled" <<<"$status"; then
    echo "==> The firmware is in setup mode: enrolling the keys"
    sudo sbctl enroll-keys --microsoft
    echo
    echo "Reboot. If Secure Boot is not on by itself afterwards, switch it on in"
    echo "the firmware setup (systemctl reboot --firmware-setup), then run this again."
  else
    echo "==> Secure Boot is off and the firmware is not in setup mode."
    echo "Put it in setup mode: systemctl reboot --firmware-setup, then in the"
    echo "Secure Boot settings clear or reset the Secure Boot keys (on HP: Security,"
    echo "Secure Boot Configuration, Clear Secure Boot Keys). Boot back and run this again."
  fi
  exit 0
fi

echo "==> Secure Boot is on"
if ! sudo cryptsetup isLuks "$DISK" 2>/dev/null; then
  echo "The disk is not encrypted, nothing to bind to the TPM. Done."
  exit 0
fi
if [ "$again" = 0 ] && sudo cryptsetup luksDump "$DISK" | grep -q systemd-tpm2; then
  echo "The disk is already bound to the TPM. Done."
  echo "(secure-host.sh --again binds it anew if it started asking for the passphrase)"
  exit 0
fi
echo "==> Binding the disk to the TPM. It asks for the disk passphrase once."
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 "$DISK"
echo
echo "Done. The next boot unlocks by itself; the passphrase stays valid as the way back in."
