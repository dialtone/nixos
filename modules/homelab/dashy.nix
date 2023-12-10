{ config, pkgs, ... }:
let
  domain = "dabass";
in
{
  # /etc/hosts entries for dashy, to bypass authelia during status checks
  networking.hosts."127.0.0.1" = map (subdomain: "${subdomain}.${domain}") [
    "bazarr"
    "deluge"
    "prowlarr"
    "radarr"
    "readarr"
    "sonarr"
    "traefik"
    "dash"
    "ha"
  ];

  services.dashy = {
    enable = true;
    #package = pkgs.dashy.override { nodejs-16_x = pkgs.nodejs_18; };
    port = 8082;
    settings = {
      pageInfo = {
        title = "dialtone";
        description = "Nyaa~~";
        navLinks = [
          {
            title = "GitHub";
            path = "https://github.com/LongerHV";
          }
          {
            title = "GitLab";
            path = "https://gitlab.com/LongerHV";
          }
          {
            title = "Notes";
            path = "https://notes.${domain}";
          }
        ];
      };
      appConfig = {
        theme = "nord-frost";
        layout = "auto";
        iconSize = "large";
        language = "pl";
        statusCheck = true;
        hideComponents.hideSettings = true;
      };
      sections = [
        {
          name = "Services";
          items = [
            {
              title = "Nextcloud";
              url = "https://nextcloud.${domain}";
              icon = "hl-nextcloud";
            }
            {
              title = "Gitea";
              url = "https://gitea.${domain}";
              icon = "hl-gitea";
            }
            {
              title = "Jellyfin";
              url = "https://jellyfin.${domain}/sso/OID/p/authelia";
              icon = "hl-jellyfin";
            }
            {
              title = "Invidious";
              url = "https://yt.${domain}";
              icon = "hl-invidious";
            }
            {
              title = "Miniflux";
              url = "https://rss.${domain}";
              icon = "hl-miniflux";
            }
            {
              title = "MinIO";
              url = "https://minio-console.${domain}";
              icon = "hl-minio";
            }
          ];
        }
        {
          name = "Utilities";
          items = [
            {
              title = "Dashy";
              url = "https://dash.${domain}";
              # icon = "hl-dashy"; # Broken for some reason
              icon = "https://raw.githubusercontent.com/walkxcode/Dashboard-Icons/main/png/dashy.png";
            }
            {
              title = "Traefik";
              url = "https://traefik.${domain}";
              icon = "hl-traefik";
            }
            {
              title = "Blocky";
              url = "https://blocky.${domain}";
              # icon = "hl-blocky"; # Waiting for a new Dashy release using proper icons repo (https://github.com/Lissy93/dashy/issues/972)
              icon = "https://raw.githubusercontent.com/walkxcode/Dashboard-Icons/main/png/blocky.png";
            }
            {
              title = "LLDAP";
              url = "https://ldap.${domain}";
            }
            {
              title = "Authelia";
              url = "https://auth.${domain}";
              icon = "hl-authelia";
            }
            rec {
              title = "Nix cache";
              url = "https://cache.${domain}";
              statusCheckUrl = "${url}/nix-cache-info";
              icon = "https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake.svg";
            }
          ];
        }
        {
          name = "Multimedia";
          items = [
            {
              title = "Sonarr";
              url = "https://sonarr.${domain}";
              icon = "hl-sonarr";
            }
            {
              title = "Radarr";
              url = "https://radarr.${domain}";
              icon = "hl-radarr";
            }
            {
              title = "Bazarr";
              url = "https://bazarr.${domain}";
              icon = "hl-bazarr";
            }
            {
              title = "Readarr";
              url = "https://readarr.${domain}";
              icon = "hl-readarr";
            }
            {
              title = "Prowlarr";
              url = "https://prowlarr.${domain}";
              icon = "hl-prowlarr";
            }
            {
              title = "Deluge";
              url = "https://deluge.${domain}";
              icon = "hl-deluge";
            }
          ];
        }
      ];
    };
  };
}
