{ config, pkgs, ... }:

{
  networking = {
    firewall = {
    	checkReversePath = false;
       	allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
    };
    nat.externalInterface = "enp7s0";

    # Dummy routing table to stop wireguard from routing all traffic
    iproute2.rttablesExtraConfig = ''
      200 vpn
    '';

    wg-quick.interfaces.wg0 = {
      table = "vpn";
      address = [ "10.64.245.75/32" ];
      listenPort = 51820;
      # this is the device key from mullvad
      privateKeyFile = config.age.secrets.wireguard_priv_key.path;
      peers = [
        {
	  # publicKey and endpoint have to match and are from the mullvad server list
          publicKey = "Ow25Pdtyqbv/Y0I0myNixjJ2iljsKcH04PWvtJqbmCk=";
          endpoint = "198.54.134.98:51820";
          allowedIPs = [ "0.0.0.0/0" ];
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
