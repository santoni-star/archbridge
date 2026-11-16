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
# Restore the stock preset when releng replaced it.
if [[ -f /etc/mkinitcpio.d/linux.preset ]]; then
  cat > /etc/mkinitcpio.d/linux.preset <<'EOF'
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux.img"
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
EOF
fi

log 'dropping the build-time local repository from pacman.conf'
if [[ -f /etc/pacman.conf ]]; then
  sed -i '/^\[archbridge-local\]/,/^$/d' /etc/pacman.conf
fi

log 'initialising the pacman keyring'
pacman-key --init
pacman-key --populate archlinux

log 'enabling services'
systemctl enable NetworkManager.service sddm.service 2>/dev/null || true
systemctl enable fstrim.timer 2>/dev/null || true
systemctl enable ufw.service 2>/dev/null || true
systemctl enable snapper-timeline.timer snapper-cleanup.timer 2>/dev/null || true

log 'done'
exit 0
