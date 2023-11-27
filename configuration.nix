# configuration in this file is shared by all hosts

{ pkgs, pkgs-unstable, inputs, ... }:
let inherit (inputs) self;
in {
  # Enable NetworkManager for wireless networking,
  # You can configure networking with "nmtui" command.
  networking.useDHCP = true;
  networking.networkmanager.enable = false;

  users.users = {
    root = {
      openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA7td9kusYnG7lTNlNP/9bGoJc/fpbVyaSAw7U96NRJYbmtWwvosAi2XpGARjPVqHwju2N9tLqtqoLksJT5vHU3/5P6BXh9h1PY3hC1qnOGXHN7heWlOAqT5Ao1VRDVxUmuUaUpo3ISPwfvRv4ZI8696ixYuW8UfoI2HqwJ5IkW58= dialtone@aiolia.local" ];
    };
  };

  ## enable GNOME desktop.
  ## You need to configure a normal, non-root user.
  # services.xserver = {
  #  enable = true;
  #  desktopManager.gnome.enable = true;
  #  displayManager.gdm.enable = true;
  # };

  ## enable ZFS auto snapshot on datasets
  ## You need to set the auto snapshot property to "true"
  ## on datasets for this to work, such as
  # zfs set com.sun:auto-snapshot=true rpool/nixos/home
  services.zfs = {
    autoSnapshot = {
      enable = false;
      flags = "-k -p --utc";
      monthly = 48;
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
  

  services.openssh = {
    enable = true;
    settings = { PasswordAuthentication = false; };
  };

  programs.ssh.startAgent = true;

  boot.zfs.forceImportRoot = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.initrd.systemd.enable = true;

  programs.git = {
    enable = true;
    config = {
      init = {
        defaultBranch = "main";
      };
      user = {
        email = "dialtone@gmail.com";
	name = "Valentino Volonghi";
      };
      aliases = {
	st = "status -sb";
	ci = "commit";
	br = "branch";
	co = "checkout";
	df = "diff";
	lg = "log -p";
	lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
	lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
	ls = "ls-files";
	cp = "cherry-pick";
	new = "ls-files --others --exclude-standard";
	added = "diff --cached --name-only";
	today = "log --stat --since='1 Day Ago' --graph --pretty=oneline --abbrev-commit --date=relative";
	plre = "pull --rebase";
	ff = "merge --ff-only";
      };
    };
  };

  security = {
    doas.enable = true;
    sudo.enable = false;
  };

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      mg # emacs-like editor
      jq # other programs
      fish
      neovim
    ;
    # By default, the system will only use packages from the
    # stable channel. i.e.
    # inherit (pkg) my-favorite-stable-package;
    # You can selectively install packages
    # from the unstable channel. Such as
    # inherit (pkgs-unstable) my-favorite-unstable-package;
    # You can also add more
    # channels to pin package version.
  };

  # Safety mechanism: refuse to build unless everything is
  # tracked by git
  #system.configurationRevision = if (self ? rev) then
  #  self.rev
  #else
  #  throw "refuse to build: git tree is dirty";

  system.stateVersion = "23.05";

  # let nix commands follow system nixpkgs revision
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  # you can then test any package in a nix shell, such as
  # $ nix shell nixpkgs#neovim
}
