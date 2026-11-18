#!/usr/bin/env bash
# Build the project's own packages into a local pacman repository.
# Must run as a regular user (makepkg refuses root) on an Arch system with
# base-devel, git and sudo available. Output: $OUT/repo (default ./out/repo).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${OUT:-$ROOT/out}"
REPO="$OUT/repo"
REPO_NAME='archbridge-local'

if [[ $EUID -eq 0 ]]; then
  echo 'build-pkgs.sh must not run as root (makepkg refuses).' >&2
  exit 1
fi

mkdir -p "$REPO"
rm -f "$REPO"/*.pkg.tar.* "$REPO/$REPO_NAME".db* "$REPO/$REPO_NAME".files*

# name:makepkg flags
#  - calamares is compiled, so its build dependencies must be installed (-s)
#  - the other packages are metapackages/config only (-d skips dependency
#    checks, because their dependencies are resolved later by mkarchiso)
packages=(
  'calamares:-sf --noconfirm --needed'
  'archbridge-base:-df --noconfirm'
  'archbridge-desktop:-df --noconfirm'
  'archbridge-wine:-df --noconfirm'
  'archbridge-welcome:-df --noconfirm'
  'archbridge-calamares-config:-df --noconfirm'
)

for entry in "${packages[@]}"; do
  name="${entry%%:*}"
  flags="${entry#*:}"
  echo "==> Building $name"
  # shellcheck disable=SC2086  # flags are intentionally word-split
  ( cd "$ROOT/pkgbuilds/$name" && PKGDEST="$REPO" makepkg $flags )
done

echo "==> Creating repository database"
repo-add "$REPO/$REPO_NAME.db.tar.zst" "$REPO"/*.pkg.tar.zst

echo "==> Done: $REPO"
ls -lh "$REPO"
