#!/usr/bin/env bash
# ArchBridge build entry point.
#
#   ./build.sh pkgs        build the local packages (Arch host, non-root)
#   ./build.sh iso         build the ISO from ./out/repo (Arch host, root)
#   ./build.sh all         pkgs + iso (inside a throwaway container, same as CI)
#   ./build.sh container   alias for "all" via Docker/Podman (any Linux host)
#   ./build.sh clean       remove ./out and ./work
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

run_container() {
  local engine
  for engine in docker podman; do
    command -v "$engine" >/dev/null 2>&1 && break
    engine=''
  done
  [[ -n "$engine" ]] || { echo 'Need docker or podman for container builds.' >&2; exit 1; }
  mkdir -p "$ROOT/out"
  "$engine" run --rm --privileged \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    -v "$ROOT:/work" -w /work \
    archlinux:latest bash ci/container-build.sh "${1:-all}"
}

case "${1:-}" in
  pkgs)       exec "$ROOT/scripts/build-pkgs.sh" ;;
  iso)        exec "$ROOT/scripts/build-iso.sh" ;;
  all|container) run_container all ;;
  clean)      rm -rf "$ROOT/out" "$ROOT/work" ;;
  -h|--help)  usage 0 ;;
  *)          usage 1 ;;
esac
