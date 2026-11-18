# ArchBridge

Thin layer over clean Arch Linux for people moving from Windows: a tuned KDE
Plasma (Wayland) desktop, the Calamares graphical installer, Btrfs with
snapshots, and Windows programs that open with a double click.

Everything comes from the official Arch repositories (including `multilib`).
There are no third-party repositories. Only Calamares is built from source,
because it is not in the official repositories.

> Status: **scaffold, not yet built end to end.** The scripts and workflows
> were written and statically checked, but the ISO has not been booted or
> installed anywhere yet. Expect to fix things on the first CI run
> (see "Known gaps").

## Layout

| Path | What it is |
| --- | --- |
| `pkgbuilds/calamares` | Calamares 3.4.2, Qt6, no bundled config |
| `pkgbuilds/archbridge-base` | base system, Btrfs tools, snapper, zram, ufw |
| `pkgbuilds/archbridge-desktop` | minimal Plasma, base applications, Baloo off |
| `pkgbuilds/archbridge-wine` | Wine Staging, `.exe` handler, default prefix bootstrap |
| `pkgbuilds/archbridge-welcome` | first-run welcome & setup assistant (Flathub, Wine, apps) |
| `pkgbuilds/archbridge-calamares-config` | installer config, branding, launcher, cleanup |
| `iso/` | overlay applied on top of the stock archiso `releng` profile |
| `scripts/build-pkgs.sh` | builds the packages into `out/repo` |
| `scripts/build-iso.sh` | builds the ISO into `out/iso` |
| `ci/container-build.sh` | the same build inside an `archlinux` container |
| `.github/workflows/ci.yml` | lint + package build on every push and pull request |
| `.github/workflows/build-iso.yml` | nightly ISO build, release on `v*` tags |

## Building

On any Linux host with Docker or Podman:

```sh
./build.sh all        # packages + ISO, result in ./out/iso
```

On an Arch host (packages as a normal user, ISO as root):

```sh
./build.sh pkgs
sudo ./build.sh iso
```

The ISO build needs roughly 15 GB of free disk space.

## CI

- **CI** (`ci.yml`): ShellCheck, yamllint, and a full package build in an
  Arch container. Packages are uploaded as an artifact.
- **Build ISO** (`build-iso.yml`): nightly at 02:17 UTC and on demand
  (`workflow_dispatch`). It uploads the ISO and `SHA256SUMS` as an artifact.
  Pushing a `v*` tag also publishes a GitHub release.
  GitHub limits release assets to 2 GiB, so a larger ISO is split into
  `.part-NN` files.

## How the pieces fit

1. `build-pkgs.sh` builds the five packages into a local pacman repo.
2. `build-iso.sh` copies the stock `releng` profile, appends `iso/packages.extra`,
   overlays `iso/airootfs`, adds a passwordless `liveuser` with Plasma
   autologin and points `pacman.conf` at the local repo.
3. The installer unpacks the live squashfs (`unpackfs`), then
   `cleanup-chroot.sh` removes the live user and autologin, restores a normal
   `mkinitcpio` setup, drops the build-time repo from `pacman.conf`,
   initialises the keyring and enables services.

## Known gaps (to do before a first public build)

- **Kernel.** The ISO uses the stock `linux` kernel, because the archiso live
  boot is wired to it. Switching to `linux-zen` means changing the releng boot
  entries and the mkinitcpio preset together. Do it as a separate step.
- **Bootloader.** GRUB is used so snapshots can be chosen in the boot menu.
  `systemd-boot` would be faster; it is an open question in the spec.
- **Wine.** `umu-launcher` is only an optional dependency, since its presence
  in the official repositories was not confirmed. The default prefix installs
  `corefonts` and `vcrun2022` on first run and needs internet access then.
- **Installer under Wayland.** `archbridge-installer` forces XWayland
  (`QT_QPA_PLATFORM=xcb`) because a root process cannot always reach the
  Wayland socket. Test this in a VM.
- **Not implemented yet:** the AI pet and gateway,
  the ArtCraft applications (see the spec, they still need compatibility
  checks), Secure Boot.

## Licence

Not chosen yet. The PKGBUILDs declare `GPL-3.0-or-later` as a placeholder.
