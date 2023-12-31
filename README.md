* Install NixOS with ZFS as root filesystem
This repo contains a minimal set of configuration for installing
NixOS, using ZFS as root filesystem.

ZFS is a modern filesystem with many features such as snapshot,
self-healing and pooled storage, see [[https://openzfs.org/wiki/Main_Page#Introduction_to_OpenZFS][Introduction]] for details.

For using this repo on your computer, see [[https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html][Documentation]].

Upon initial installation, only the bootloader, mountpoints and root
password are configured.

- Refer to =man configuration.nix= for available options;
- Search for available packages with [[https://search.nixos.org/packages][Package Search]];
- Search for options with [[https://search.nixos.org/options][Option Search]].

[[https://codeberg.org/m0p/dotfiles][My personal dotfiles repo]] contains an example of desktop configuration
based on sway, tmux and Emacs.


# setup post reboot with existing disk
```
zpool import -f rpool
zpool import -f bpool
DISK='/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNM0W613358M_1'
MNT=$(mktemp -d)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
if ! command -v git; then nix-env -f '<nixpkgs>' -iA git; fi
if ! command -v nvim; then nix-env -f '<nixpkgs>' -iA neovim; fi

mount -t zfs rpool/nixos/root "${MNT}"/
mount -t zfs rpool/nixos/home "${MNT}"/home
mount -t zfs bpool/nixos/root "${MNT}"/boot
mount -t zfs rpool/nixos/var/lib "${MNT}"/var/lib
mount -t zfs rpool/nixos/var/log "${MNT}"/var/log

mkdir -p "${MNT}"/etc/nixos
mkdir -p "${MNT}"/nix
mkdir -p "${MNT}"/persist
mount -t zfs rpool/nixos/config "${MNT}"/etc/nixos
mount -t zfs rpool/nixos/nix "${MNT}"/nix
mount -t zfs rpool/nixos/persist "${MNT}"/persist


mount -t vfat -o iocharset=iso8859-1 /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNM0W613358M_1-part1 "${MNT}"/boot/efis/nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNM0W613358M_1-part1


nix flake update --commit-lock-file \
  "git+file://${MNT}/etc/nixos"

nixos-install \
--root "${MNT}" \
--no-root-passwd \
--flake "git+file://${MNT}/etc/nixos#dabass"
```
