{ config, lib, pkgs, vars, ... }:
let
  dataDir = "${vars.serviceConfigRoot}/hermes";
  workspaceDir = "${vars.mainArray}/Hermes"; # Samba share, see samba.nix

  # Hermes runs as the samba `share` user so files in the workspace are
  # editable from both sides.
  uid = toString config.users.users.share.uid;
  gid = toString config.users.groups.share.gid;

  # Seeded on first start only; after that Hermes (dashboard/CLI) owns it.
  # Anything not set here falls back to Hermes' built-in defaults.
  seedConfig = pkgs.writeText "hermes-config.yaml" ''
    _config_version: 49
    model:
      provider: "anthropic"
      default: "claude-sonnet-5-5"
    terminal:
      backend: "local"
      cwd: "/workspace"
    approvals:
      mode: smart
    dashboard:
      # Traefik reaches the container through docker-proxy on the default bridge gateway.
      trusted_proxies:
        - "172.17.0.1"
  '';
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.services.hermes-seed = {
    description = "Seed Hermes data directory";
    before = [ "docker-hermes.service" ];
    requiredBy = [ "docker-hermes.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0750 -o ${uid} -g ${gid} ${dataDir}
      if [ ! -e ${dataDir}/config.yaml ]; then
        install -m 0640 -o ${uid} -g ${gid} ${seedConfig} ${dataDir}/config.yaml
      fi
    '';
  };

  virtualisation.oci-containers.containers.hermes = {
    image = "nousresearch/hermes-agent:v2026.9.24";
    cmd = [ "gateway" "run" ];
    environment = {
      HERMES_UID = uid;
      HERMES_GID = gid;
      HERMES_DASHBOARD = "1";
      HERMES_DASHBOARD_HOST = "0.0.0.0";
      HERMES_DASHBOARD_PUBLIC_URL = "http://hermes.${vars.domainName}";
      API_SERVER_HOST = "0.0.0.0";
      HASS_URL = "http://host.docker.internal:8123";
      WHATSAPP_MODE = "bot";
    };
    # ANTHROPIC_API_KEY, dashboard login, API_SERVER_KEY and platform credentials.
    # See secrets/hermesEnv.template and scripts/setup-hermes.sh.
    environmentFiles = [ config.age.secrets.hermesEnv.path ];
    volumes = [
      "${dataDir}:/opt/data"
      "${workspaceDir}:/workspace"
    ];
    ports = [
      "127.0.0.1:9119:9119" # dashboard, via traefik
      "127.0.0.1:8642:8642" # API server, via traefik
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--memory=4g"
      "--cpus=2"
      "--shm-size=1g"
    ];
  };
}
