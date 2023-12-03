{ config, lib, pkgs, vars, ... }:

{
    users.groups.multimedia = { };
    users.users."dialtone".extraGroups = [ "multimedia" ];

    #systemd.tmpfiles.rules = [
    #   "d ${vars.mainArray}/media 0775 root multimedia - -"
    #];

    #homelab.traefik = {
    #  enable = true;
    #  services = {
    #    jellyfin.port = 8096;
    #    sonarr.port = 8989;
    #    radarr.port = 7878;
    #    prowlarr.port = 9696;
    #    readarr.port = 8787;
    #    bazarr.port = config.services.bazarr.listenPort;
    #    deluge.port = config.services.deluge.web.port;
    #  };

    #};

    environment.systemPackages = with pkgs; [
      jellyfin-ffmpeg
      intel-ocl
      libva-utils
    ];

    services = {
      jellyfin = {
        enable = true;
        group = "multimedia";
	openFirewall = true;
      };
      sonarr = { enable = true; openFirewall = true; group = "multimedia"; };
      radarr = { enable = true; openFirewall = true; group = "multimedia"; };
      bazarr = { enable = true; group = "multimedia"; };
      readarr = { enable = true; group = "multimedia"; };
      prowlarr = { enable = true; };
      deluge = {
        enable = true;
        group = "multimedia";
	web = {
	  enable = true;
	  openFirewall = true;
	};
        dataDir = "${vars.mainArray}/media/torrent";
        declarative = true;
        config = {
          enabled_plugins = [ "Label" ];
          outgoing_interface = "wg0";
        };
        authFile = pkgs.writeTextFile {
          name = "deluge-auth";
          text = ''
            localclient::10
          '';
        };
      };
    };

    users.users.jellyfin.extraGroups = ["render" "share"];
    users.users.deluge.extraGroups = ["share"];
}
