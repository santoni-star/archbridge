#!/usr/bin/env bash
# Runs inside a fresh archlinux:latest container (used by CI and ./build.sh).
#   container-build.sh pkgs   build packages only
#   container-build.sh all    build packages, then the ISO (needs --privileged)
#
# Expects the repository mounted at /work. Results land in /work/out.
# Optional environment:
#   WORK_DIR   scratch directory for mkarchiso (default /var/tmp/archbridge-work)
#   HOST_UID / HOST_GID   owner for the files copied back to /work/out
set -euo pipefail

MODE="${1:-all}"
SRC=/work
BUILD_HOME=/home/builder
BUILD_SRC="$BUILD_HOME/src"
BUILD_OUT="$BUILD_HOME/out"

case "$MODE" in pkgs|all) ;; *) echo "usage: $0 pkgs|all" >&2; exit 2 ;; esac

echo '==> Preparing the container'
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman -Syu --noconfirm --needed base-devel git sudo archiso

id builder >/dev/null 2>&1 || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder

# Work on a copy so the bind-mounted checkout keeps its ownership.
rm -rf "$BUILD_SRC" "$BUILD_OUT"
mkdir -p "$BUILD_SRC" "$BUILD_OUT"
tar -C "$SRC" --exclude=./out --exclude=./work --exclude=./.git -cf - . | tar -C "$BUILD_SRC" -xf -
chown -R builder:builder "$BUILD_HOME"

finish() {
  mkdir -p "$SRC/out"
  rm -rf "$SRC/out/repo" "$SRC/out/iso"
  [[ -d "$BUILD_OUT/repo" ]] && cp -r "$BUILD_OUT/repo" "$SRC/out/repo"
  [[ -d "$BUILD_OUT/iso" ]] && cp -r "$BUILD_OUT/iso" "$SRC/out/iso"
  if [[ -n "${HOST_UID:-}" ]]; then
    chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$SRC/out"
  fi
}
trap finish EXIT

echo '==> Building packages'
runuser -u builder -- env OUT="$BUILD_OUT" bash "$BUILD_SRC/scripts/build-pkgs.sh"

if [[ "$MODE" == 'all' ]]; then
  echo '==> Building ISO'
  OUT="$BUILD_OUT" WORK_DIR="${WORK_DIR:-/var/tmp/archbridge-work}" bash "$BUILD_SRC/scripts/build-iso.sh"
fi
