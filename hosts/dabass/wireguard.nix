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
      dns = [ "1.1.1.1" ];
      privateKeyFile = config.age.secrets.mullvad_priv_key.path;
      peers = [
        {
          publicKey = "WfJz/x8yxsukwqLJeJq8c9/1JOHOtZ+Vs+wPSUiRPxQ=";
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "193.32.127.69:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
