{ config, lib, pkgs, vars, ... }:

let
  cfg = config.zfs-root.boot;
  inherit (lib) mkIf types mkDefault mkOption mkMerge strings;
  inherit (builtins) head toString map tail;
in {
  imports = [./snapraid.nix];

  options.zfs-root.boot = {
    enable = mkOption {
      description = "Enable root on ZFS support";
      type = types.bool;
      default = true;
    };
    luks.enable = mkOption {
      description = "Use luks encryption";
      type = types.bool;
      default = false;
    };
    devNodes = mkOption {
      description = "Specify where to discover ZFS pools";
      type = types.str;
      apply = x:
        assert (strings.hasSuffix "/" x
          || abort "devNodes '${x}' must have trailing slash!");
        x;
      default = "/dev/disk/by-id/";
    };
    bootDevices = mkOption {
      description = "Specify boot devices";
      type = types.nonEmptyListOf types.str;
    };
    immutable.enable = mkOption {
      description = "Enable root on ZFS immutable root support";
      type = types.bool;
      default = false;
    };
    removableEfi = mkOption {
      description = "install bootloader to fallback location";
      type = types.bool;
      default = true;
    };
    partitionScheme = mkOption {
      default = {
        biosBoot = "-part4";
        efiBoot = "-part1";
        bootPool = "-part2";
        rootPool = "-part3";
      };
      description = "Describe on disk partitions";
      type = types.attrsOf types.str;
    };
  };
  config = mkIf (cfg.enable) (mkMerge [
    {
      zfs-root.fileSystems.datasets = {
        # rpool/path/to/dataset = "/path/to/mountpoint"
        "rpool/nixos/home" = mkDefault "/home";
        "rpool/nixos/var/lib" = mkDefault "/var/lib";
        "rpool/nixos/var/log" = mkDefault "/var/log";
        "rpool/nixos/config" = mkDefault "/etc/nixos";
        "rpool/nixos/nix" = mkDefault "/nix";
        "rpool/nixos/persist" = mkDefault "/persist";
        "bpool/nixos/root" = "/boot";
      };
    }
    (mkIf cfg.luks.enable {
      boot.initrd.luks.devices = mkMerge (map (diskName: {
        "luks-rpool-${diskName}${cfg.partitionScheme.rootPool}" = {
          device = (cfg.devNodes + diskName + cfg.partitionScheme.rootPool);
          allowDiscards = true;
          bypassWorkqueues = true;
        };
      }) cfg.bootDevices);
    })
    (mkIf (!cfg.immutable.enable) {
      zfs-root.fileSystems.datasets = { "rpool/nixos/root" = "/"; };
    })
    (mkIf cfg.immutable.enable {
      zfs-root.fileSystems = {
        datasets = {
          # rpool/path/to/dataset = "/path/to/mountpoint"
          "rpool/nixos/empty" = "/";
          "rpool/nixos/root" = "/oldroot";
        };
        bindmounts = {
          # /bindmount/source = /bindmount/target
          "/oldroot/nix" = "/nix";
          "/oldroot/etc/nixos" = "/etc/nixos";
        };
      };
      boot.initrd.postDeviceCommands = ''
        if ! grep -q zfs_no_rollback /proc/cmdline; then
          zpool import -N rpool
          zfs rollback -r rpool/nixos/empty@start
          zpool export -a
        fi
      '';
    })
    {
      zfs-root.fileSystems = {
        efiSystemPartitions =
          (map (diskName: diskName + cfg.partitionScheme.efiBoot)
            cfg.bootDevices);
      };

      programs.fuse.userAllowOther = true;
      environment.systemPackages = with pkgs; [
        gptfdisk
        xfsprogs
        parted
        snapraid
        mergerfs
        mergerfs-tools
      ];

      # storage array
      fileSystems."/mnt/data1" =
      { device = "/dev/disk/by-label/data1";
        fsType = "xfs";
      };
      
      fileSystems."/mnt/data2" =
      { device = "/dev/disk/by-label/data2";
        fsType = "xfs";
      };
      
      fileSystems."/mnt/parity1" =
      { device = "/dev/disk/by-label/parity1";
        fsType = "xfs";
      };

      fileSystems.${vars.slowArray} = 
      { device = "/mnt/data*";
        options = [
            "defaults"
            "allow_other"
            "moveonenospc=1"
            "minfreespace=1000G"
            "func.getattr=newest"
            "fsname=mergerfs_slow"
            "uid=994"
            "gid=993"
            "umask=002"
            "x-mount.mkdir"
        ];
        fsType = "fuse.mergerfs";
      };

      fileSystems.${vars.mainArray} = 
      { device = "${vars.cacheArray}:${vars.slowArray}";
        options = [
          "category.create=lfs"
            "defaults"
            "allow_other"
            "moveonenospc=1"
            "minfreespace=500G"
            "func.getattr=newest"
            "fsname=user"
            "uid=994"
            "gid=993"
            "umask=002"
            "x-mount.mkdir"
        ];
        fsType = "fuse.mergerfs";
      };

      boot = {
        # kernelPackages = mkDefault config.boot.zfs.package.latestCompatibleLinuxPackages;
	kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
        # initrd.availableKernelModules = cfg.availableKernelModules;
        # kernelParams = cfg.kernelParams;
        initrd.systemd.emergencyAccess = true;
	initrd.systemd.enable = true;
        supportedFilesystems = [ "zfs" ];
        zfs = {
          devNodes = cfg.devNodes;
          forceImportRoot = mkDefault false;
        };
        loader = {
          efi = {
            canTouchEfiVariables = (if cfg.removableEfi then false else true);
            efiSysMountPoint = ("/boot/efis/" + (head cfg.bootDevices)
              + cfg.partitionScheme.efiBoot);
          };
          generationsDir.copyKernels = true;
          grub = {
            enable = true;
            #devices = (map (diskName: cfg.devNodes + diskName) cfg.bootDevices);
            device = "nodev";
            efiInstallAsRemovable = cfg.removableEfi;
            copyKernels = true;
            efiSupport = true;
            zfsSupport = true;
            extraInstallCommands = (toString (map (diskName: ''
              set -x
              ${pkgs.coreutils-full}/bin/cp -r ${config.boot.loader.efi.efiSysMountPoint}/EFI /boot/efis/${diskName}${cfg.partitionScheme.efiBoot}
              set +x
            '') (tail cfg.bootDevices)));
          };
        };
      };
    }
  ]);
}
