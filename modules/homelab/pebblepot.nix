{ config, lib, pkgs, inputs, vars, ... }:
let
  # Source-only flake input (flake = false); `nix flake update pebblepot` moves it.
  src = inputs.pebblepot;
  image = "pebblepot:${src.shortRev}";

  # The image runs as this fixed non-root user (see the Pebblepot Dockerfile).
  uid = "10001";
  gid = "10001";

  dataDir = "${vars.serviceConfigRoot}/pebblepot";
  db = "${dataDir}/pebblepot.sqlite3";
  # On the SnapRAID-protected array, inside the Backups samba share.
  backupDir = "${vars.mainArray}/Backups/Pebblepot";

  docker = config.virtualisation.docker.package;
  timeZone = config.time.timeZone;

  # Nightly consistent copy of the live WAL database. Never copies the raw file.
  # Runs as root: SQLite gives any -wal/-shm it creates the database owner's uid.
  backup = pkgs.writeShellApplication {
    name = "pebblepot-backup";
    runtimeInputs = [ pkgs.sqlite pkgs.coreutils pkgs.findutils pkgs.gnugrep ];
    text = ''
      db=${db}
      dest=${backupDir}
      keep_daily=30
      keep_monthly=12

      if [ ! -f "$db" ]; then
        echo "no database at $db" >&2
        exit 1
      fi
      mkdir -p "$dest"

      name="pebblepot-$(date +%Y-%m-%d_%H%M%S).sqlite3"
      tmp="$dest/.$name.tmp"
      rm -f "$tmp"
      sqlite3 "$db" "VACUUM INTO '$tmp'"
      check=$(sqlite3 "$tmp" "PRAGMA integrity_check")
      if [ "$check" != "ok" ]; then
        echo "integrity check failed on the new copy: $check" >&2
        rm -f "$tmp"
        exit 1
      fi
      mv "$tmp" "$dest/$name"
      echo "wrote $dest/$name"

      # Keep the newest copy of each of the last $keep_daily days and of each of
      # the last $keep_monthly months that have a copy; delete the rest.
      declare -A days=() months=()
      mapfile -t copies < <(find "$dest" -maxdepth 1 -type f -printf '%f\n' \
        | grep -E '^pebblepot-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}\.sqlite3$' | sort -r)
      for f in "''${copies[@]}"; do
        day=''${f:10:10}
        month=''${f:10:7}
        keep=0
        if [ -z "''${days[$day]:-}" ] && [ "''${#days[@]}" -lt "$keep_daily" ]; then
          days[$day]=1
          keep=1
        fi
        if [ -z "''${months[$month]:-}" ] && [ "''${#months[@]}" -lt "$keep_monthly" ]; then
          months[$month]=1
          keep=1
        fi
        if [ "$keep" -eq 0 ]; then
          rm -f "$dest/$f"
          echo "pruned $f"
        fi
      done
    '';
  };

  # pebblepot-restore <backup-file>: swap a backup in for the live database.
  restore = pkgs.writeShellApplication {
    name = "pebblepot-restore";
    runtimeInputs = [ pkgs.sqlite pkgs.coreutils ];
    text = ''
      db=${db}
      if [ "$#" -ne 1 ]; then
        echo "usage: pebblepot-restore <backup-file>" >&2
        echo "backups are in ${backupDir}" >&2
        exit 2
      fi
      if [ "$(id -u)" -ne 0 ]; then
        echo "pebblepot-restore must run as root (doas pebblepot-restore ...)" >&2
        exit 1
      fi
      backup=$(realpath -e "$1")
      check=$(sqlite3 -readonly "$backup" "PRAGMA integrity_check")
      if [ "$check" != "ok" ]; then
        echo "$backup is not a healthy SQLite database: $check" >&2
        exit 1
      fi

      systemctl stop docker-pebblepot.service
      trap 'systemctl start docker-pebblepot.service' EXIT

      # Keep what is being replaced, -wal included, next to the backups.
      if [ -f "$db" ]; then
        saved="${backupDir}/pre-restore-$(date +%Y-%m-%d_%H%M%S).sqlite3"
        mkdir -p ${backupDir}
        sqlite3 "$db" "VACUUM INTO '$saved'"
        echo "saved the current database as $saved"
      fi

      install -m 0640 -o ${uid} -g ${gid} "$backup" "$db.restore"
      rm -f "$db-wal" "$db-shm"
      mv "$db.restore" "$db"
      echo "restored $backup"
    '';
  };
in
{
  assertions = [{
    assertion = timeZone != null;
    message = "pebblepot.nix needs time.timeZone to set PEBBLEPOT_TIME_ZONE";
  }];

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  # The container exits with "unable to open database file" unless it owns this.
  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 ${uid} ${gid} -" ];

  # Builds the image from the pinned source on first start after an update
  # (a few minutes the first time); a no-op when the tag already exists.
  systemd.services.pebblepot-build = {
    description = "Build the Pebblepot image ${image}";
    before = [ "docker-pebblepot.service" ];
    requiredBy = [ "docker-pebblepot.service" ];
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    path = [ docker ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "30min";
    };
    script = ''
      if docker image inspect ${image} > /dev/null 2>&1; then
        echo "${image} already built"
        exit 0
      fi
      docker build --tag ${image} ${src}
    '';
  };

  virtualisation.oci-containers.containers.pebblepot = {
    inherit image;
    pull = "never";
    environment = {
      PEBBLEPOT_LISTEN_ADDR = "0.0.0.0";
      PEBBLEPOT_PORT = "8070";
      PEBBLEPOT_DATA_DIR = "/data";
    } // lib.optionalAttrs (timeZone != null) {
      PEBBLEPOT_TIME_ZONE = timeZone;
    };
    volumes = [ "${dataDir}:/data" ];
    ports = [ "127.0.0.1:8070:8070" ]; # via traefik, pebblepot.dabass
  };

  systemd.services.docker-pebblepot.onFailure = [ "pebblepot-notify@%N.service" ];

  systemd.services.pebblepot-backup = {
    description = "Back up the Pebblepot database";
    onFailure = [ "pebblepot-notify@%N.service" ];
    unitConfig.RequiresMountsFor = [ dataDir vars.mainArray ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backup}/bin/pebblepot-backup";
    };
  };

  systemd.timers.pebblepot-backup = {
    description = "Nightly Pebblepot database backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
    };
  };

  # Reports a failed unit (the instance name) through notify, like snapraid does.
  systemd.services."pebblepot-notify@" = {
    description = "Notify about failed %i";
    serviceConfig.Type = "oneshot";
    scriptArgs = "%i";
    script = ''
      message=$(journalctl --unit="$1" -n 20 --no-pager)
      /run/current-system/sw/bin/notify -s "''${MONITOR_SERVICE_RESULT:-failed}" -t "Pebblepot: $1" -m "$message"
    '';
  };

  environment.systemPackages = [ restore ];
}
