#!/usr/bin/env bash
# Runs inside the freshly installed system (Calamares chroot) after unpackfs.
# Removes everything that only makes sense on the live medium and prepares
# the target to boot on its own.
set -uo pipefail

log() { printf '[archbridge-cleanup] %s\n' "$*"; }

log 'removing live user and live-only configuration'
userdel -r liveuser 2>/dev/null || true
rm -f /etc/sudoers.d/10-archbridge-live /etc/sudoers.d/g_wheel
rm -f /etc/sddm.conf.d/autologin.conf
rm -rf /etc/systemd/system/getty@tty1.service.d
rm -f /etc/motd
rm -f /usr/local/bin/choose-mirror /usr/local/bin/Installation_guide

log 'switching mkinitcpio from the live (archiso) setup to a normal one'
rm -f /etc/mkinitcpio.conf.d/archiso.conf
rm -f /etc/mkinitcpio.d/linux.preset
cat > /etc/mkinitcpio.d/linux-zen.preset <<'EOF'
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-zen"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux-zen.img"
fallback_image="/boot/initramfs-linux-zen-fallback.img"
fallback_options="-S autodetect"
EOF

log 'dropping the build-time local repository from pacman.conf'
if [[ -f /etc/pacman.conf ]]; then
  sed -i '/^\[archbridge-local\]/,/^$/d' /etc/pacman.conf
fi

log 'initialising the pacman keyring'
pacman-key --init
pacman-key --populate archlinux

log 'enabling services'
systemctl enable NetworkManager.service sddm.service 2>/dev/null || true
systemctl enable bluetooth.service cups.service 2>/dev/null || true
systemctl enable fstrim.timer 2>/dev/null || true
systemctl enable ufw.service 2>/dev/null || true

if [[ "$(findmnt -n -o FSTYPE /)" == 'btrfs' ]] && command -v snapper >/dev/null 2>&1; then
  log 'configuring snapper for /'
  if mountpoint -q /.snapshots; then
    umount /.snapshots
  fi
  rmdir /.snapshots 2>/dev/null || true
  snapper --no-dbus -c root create-config /
  btrfs subvolume delete /.snapshots 2>/dev/null || rm -rf /.snapshots
  mkdir -p /.snapshots
  chmod 750 /.snapshots
  mount /.snapshots 2>/dev/null || true
  systemctl enable snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service 2>/dev/null || true
fi

log 'done'
exit 0
