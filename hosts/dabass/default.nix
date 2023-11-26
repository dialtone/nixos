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

  hardware.opengl.enable = true;                                                                                                                                                                              hardware.opengl.driSupport = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelParams = [ "pcie_aspm=force" "consoleblank=60" ];
  networking.hostId = "7af06fcb";
  networking.hostName = "dabass";
  time.timeZone = "America/Los_Angeles";

  powerManagement.powertop.enable = true;


  # import preconfigured profiles
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # (modulesPath + "/profiles/hardened.nix")
    # (modulesPath + "/profiles/qemu-guest.nix")
  ];

  environment.systemPackages = with pkgs; [
    pciutils
    hdparm
    hd-idle
    hddtemp
    smartmontools
    go
    gotools
    gopls
    go-outline
    gocode
    gopkgs
    gocode-gomod
    godef
    golint
    powertop
    cpufrequtils
    gnumake
    gcc
    intel-gpu-tools
    lm_sensors
    ripgrep
    iotop
  ];
}
