{ config, pkgs, lib, inputs, modulesPath, nixpkgs, ... }: {
  zfs-root = {
    boot = {
      devNodes = "/dev/disk/by-id/";
      bootDevices = [ "nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNM0W613358M_1" ];
      immutable.enable = false;
      removableEfi = true;
      luks.enable = false;
    };
  };

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelParams = [ "pcie_aspm=force" "consoleblank=60" ];
  boot.kernelModules = [ "kvm-amd" "nct6775" ];
  networking.hostId = "7af06fcb";
  networking.hostName = "dabass";
  time.timeZone = "America/Los_Angeles";

  powerManagement.powertop.enable = true;


  # import preconfigured profiles
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    ./boot.nix
    ./filesystems.nix
    ./wireguard.nix
    (modulesPath + "/installer/scan/not-detected.nix")

    # (modulesPath + "/profiles/hardened.nix")
    # (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nix.settings.trusted-users = [ "dialtone" ];

  users = {
    users = {
      dialtone = {
        shell = pkgs.fish;
        uid = 1000;
        isNormalUser = true;
	passwordFile = config.age.secrets.hashedUserPassword.path;
        extraGroups = [ "wheel" "users" ];
        group = "dialtone";
        openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA7td9kusYnG7lTNlNP/9bGoJc/fpbVyaSAw7U96NRJYbmtWwvosAi2XpGARjPVqHwju2N9tLqtqoLksJT5vHU3/5P6BXh9h1PY3hC1qnOGXHN7heWlOAqT5Ao1VRDVxUmuUaUpo3ISPwfvRv4ZI8696ixYuW8UfoI2HqwJ5IkW58= dialtone@aiolia.local" ];
      };
    };
    groups = {
      dialtone = {
        gid = 1000;
      };
    };
  };

  programs.fish.enable = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
    
      #pkgs.vaapiVdpau
      #pkgs.libvdpau-va-gl
    ];
  };

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
