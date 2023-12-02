{ lib, inputs, ... }: 
{
  age.identityPaths = ["/persist/nixos-keys/id_ed25519"];
  age.secrets.hashedUserPassword = lib.mkDefault {
    file = ./hashedUserPassword.age;
  };
  age.secrets.sambaPassword = lib.mkDefault {
    file = ./sambaPassword.age;
  };

  # Wireguard
  age.secrets.wireguard_priv_key.file = ./wgPrivateKey.age;
  age.secrets.mullvad_priv_key.file = ./wgMullvadPrivateKey.age;
}
