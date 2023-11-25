{ config, pkgs, lib, inputs, modulesPath, ... }: {
  zfs-root = {
    boot = {
      devNodes = "/dev/disk/by-id/";
      bootDevices = [ "nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNM0W613358M_1" ];
      immutable.enable = false;
      removableEfi = true;
      luks.enable = false;
    };
  };
  boot.initrd.availableKernelModules = [  "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelParams = [ ];
  networking.hostId = "7af06fcb";
  # read changeHostName.txt file.
  networking.hostName = "exampleHost";
  time.timeZone = "Europe/Berlin";

  # import preconfigured profiles
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # (modulesPath + "/profiles/hardened.nix")
    # (modulesPath + "/profiles/qemu-guest.nix")
  ];
}
