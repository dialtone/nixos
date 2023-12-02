{ lib, inputs, ... }: 
{
  age.identityPaths = ["/persist/nixos-keys/id_ed25519"];
  age.secrets.hashedUserPassword = lib.mkDefault {
    file = ./hashedUserPassword.age;
  };
  age.secrets.sambaPassword = lib.mkDefault {
    file = ./sambaPassword.age;
  };
}
