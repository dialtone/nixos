{ config, pkgs, lib, ... }: 
{
  nix.settings.trusted-users = [ "dialtone" ];

  users = {
    users = {
      dialtone = {
        shell = pkgs.fish;
        uid = 1000;
        isNormalUser = true;
	hashedPassword = "$6$SKTDmY/8dJP02Zb1$F6seN3mKIgvjybeQfIiZKQy22hLfZsojzZERpJW0tE6EglI/cZZq6cinhrsuCGXHM5yVX/Pnr1s2fYG/kE4l80";
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

}
