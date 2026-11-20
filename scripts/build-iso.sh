#!/usr/bin/env bash
# Build the live/installer ISO with archiso.
#
# Starts from the stock "releng" profile shipped with the archiso package,
# overlays the project's customisations on top, and runs mkarchiso.
# Needs root and the local package repo produced by scripts/build-pkgs.sh.
#
# Environment:
#   OUT       output directory        (default: ./out)
#   WORK_DIR  scratch space, ~15 GB   (default: ./work)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${OUT:-$ROOT/out}"
WORK="${WORK_DIR:-$ROOT/work}"
REPO="$OUT/repo"
ISO_OUT="$OUT/iso"
RELENG='/usr/share/archiso/configs/releng'
PROFILE="$WORK/profile"
AIROOTFS="$PROFILE/airootfs"

if [[ $EUID -ne 0 ]]; then
  echo 'mkarchiso needs root.' >&2
  exit 1
fi
[[ -d "$RELENG" ]] || { echo "archiso is not installed ($RELENG missing)." >&2; exit 1; }
[[ -f "$REPO/archbridge-local.db.tar.zst" ]] || {
  echo "Local repo not found in $REPO - run scripts/build-pkgs.sh first." >&2
  exit 1
}

echo '==> Preparing profile'
rm -rf "$PROFILE" "$WORK/tmp"
mkdir -p "$WORK" "$ISO_OUT"
cp -r "$RELENG" "$PROFILE"

# 1. Package list: stock releng list (with linux-zen) + project additions.
sed -i 's/^linux$/linux-zen/' "$PROFILE/packages.x86_64"
grep -vE '^[[:space:]]*(#|$)' "$ROOT/iso/packages.extra" >> "$PROFILE/packages.x86_64"

# 2. Filesystem overlay.
cp -a "$ROOT/iso/airootfs/." "$AIROOTFS/"

# 3. Live account: appended to the stock files instead of replacing them.
for f in passwd shadow group gshadow; do
  cat "$ROOT/iso/accounts/$f" >> "$AIROOTFS/etc/$f"
done

# 4. Drop releng networking in favour of NetworkManager.
rm -f "$AIROOTFS/etc/resolv.conf"
rm -f "$AIROOTFS"/etc/systemd/system/multi-user.target.wants/systemd-networkd.service \
      "$AIROOTFS"/etc/systemd/system/multi-user.target.wants/systemd-resolved.service \
      "$AIROOTFS"/etc/systemd/system/sockets.target.wants/systemd-networkd.socket \
      "$AIROOTFS"/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service \
      "$AIROOTFS"/etc/systemd/system/sysinit.target.wants/systemd-resolved.service

# 5. Services and default target.
mkdir -p "$AIROOTFS/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/sddm.service "$AIROOTFS/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
  "$AIROOTFS/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/graphical.target "$AIROOTFS/etc/systemd/system/default.target"

# 6. Branding and linux-zen kernel paths in boot menus & mkinitcpio preset.
find "$PROFILE/syslinux" "$PROFILE/grub" "$PROFILE/efiboot" -type f -print0 2>/dev/null |
  xargs -0 -r sed -i \
    's/Arch Linux install medium/ArchBridge Live CD (Try or Install)/g; s/Arch Linux/ArchBridge/g; s/vmlinuz-linux/vmlinuz-linux-zen/g; s/initramfs-linux/initramfs-linux-zen/g'
if [[ -f "$AIROOTFS/etc/mkinitcpio.d/linux.preset" ]]; then
  sed -i 's/vmlinuz-linux/vmlinuz-linux-zen/g; s/initramfs-linux/initramfs-linux-zen/g' \
    "$AIROOTFS/etc/mkinitcpio.d/linux.preset"
  mv "$AIROOTFS/etc/mkinitcpio.d/linux.preset" "$AIROOTFS/etc/mkinitcpio.d/linux-zen.preset"
fi

# 7. profiledef.sh (it is sourced by bash, so $(date) is expanded by mkarchiso)
# shellcheck disable=SC2016
sed -i -E \
  -e 's|^iso_name=.*|iso_name="archbridge"|' \
  -e 's|^iso_label=.*|iso_label="ARCHBRIDGE_$(date +%Y%m)"|' \
  -e 's|^iso_publisher=.*|iso_publisher="ArchBridge"|' \
  -e 's|^iso_application=.*|iso_application="ArchBridge live/installer"|' \
  "$PROFILE/profiledef.sh"
cat >> "$PROFILE/profiledef.sh" <<'EOF'

file_permissions+=(
  ["/etc/sudoers.d/10-archbridge-live"]="0:0:440"
  ["/home/liveuser"]="1000:1000:750"
  ["/home/liveuser/Desktop"]="1000:1000:750"
  ["/home/liveuser/Desktop/archbridge-installer.desktop"]="1000:1000:755"
)
EOF

# 8. pacman.conf used for the build: multilib on, local repo first.
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$PROFILE/pacman.conf"
sed -i "/^\[core\]/i [archbridge-local]\nSigLevel = Optional TrustAll\nServer = file://$REPO\n" "$PROFILE/pacman.conf"

echo '==> Running mkarchiso'
mkarchiso -v -w "$WORK/tmp" -o "$ISO_OUT" "$PROFILE"

echo "==> Done:"
ls -lh "$ISO_OUT"
