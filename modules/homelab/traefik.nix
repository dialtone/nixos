{config, lib, ...}:
let 
  mkRouter = name: value:
    {
      rule = "Host(`${name}.dabass`)";
      service = name;
      middlewares = "local-ip-whitelist";
    };
  mkService = name: value: {
    loadBalancer = {
      servers = [
        { url = "http://localhost:${builtins.toString value.port}"; }
      ];
    };
  };
  apps = {
    ha.port = 8123;
    jellyfin.port = 8096;
    sonarr.port = 8989;
    radarr.port = 7878;
    prowlarr.port = 9696;
    readarr.port = 8787;
    bazarr.port = config.services.bazarr.listenPort;
    deluge.port = config.services.deluge.web.port;
  };
in
{
  networking.firewall.allowedTCPPorts = [ 8080 80 443 ];

  services.traefik = {
    enable = true;
    staticConfigOptions = {
      entryPoints.web.address = ":80";
      api = {
        dashboard = true;
	insecure = true;
      };
      global = {
        checknewversion = false;
        sendanonymoususage = false;
      };
    };
    dynamicConfigOptions = {
      http = {
        routers = lib.mkMerge [
	  (builtins.mapAttrs mkRouter apps)
	  {
	    traefik = {
	      rule = "Host(`traefik.dabass`)";
	      service = "api@internal";
              middlewares = "local-ip-whitelist";
	    };
	  }
	];
	services = (builtins.mapAttrs mkService apps);

        middlewares = {
          localhost-only.IPWhitelist.sourceRange = [ "127.0.0.1/32" ];
          local-ip-whitelist.IPWhiteList = {
            sourceRange = [
              "127.0.0.1/32"
              "10.0.0.0/8"
              "172.16.0.0/12"
              "192.168.0.0/16"
            ];
          };
        };
      };
    };
  };
}
