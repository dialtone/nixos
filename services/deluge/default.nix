{config, lib, pkgs, ... }:
let
  # Track NixOS unstable via nix-channel, or replace it with something like niv at your own discretion
  # nix-channel --add http://nixos.org/channels/nixos-unstable nixos-unstable
  unstable = import <nixos-unstable> {};
in
{
  nixpkgs.overlays = [
    (self: super: {
      inherit (unstable) deluge;
    })
  ];

  disabledModules = [
    "services/torrent/deluge.nix"
  ];

  imports = [
    <nixos-unstable/nixos/modules/services/torrent/deluge.nix>
  ];

  services.deluge = {
    enable = true;
  }
}
