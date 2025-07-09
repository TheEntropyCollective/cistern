{ config, pkgs, lib, ... }:

{
  # Monitoring and observability for media server fleet
  
  # Prometheus node exporter for metrics
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [
      "systemd"
      "processes"
      "interrupts"
      "ksmd"
      "logind"
      "meminfo_numa"
      "mountstats"
      "network_route"
      "ntp"
      "systemd"
      "tcpstat"
      "wifi"
    ];
    openFirewall = true;
  };

  # Loki for log aggregation - temporarily disabled due to configuration issues
  services.loki = {
    enable = false;
    configuration = {
      server.http_listen_port = 3100;
      auth_enabled = false;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
      };

      schema_config = {
        configs = [{
          from = "2022-06-01";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v11";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
          cache_ttl = "24h";
        };

        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/var/lib/loki";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        retention_delete_worker_count = 150;
      };
    };
  };

  # Promtail for log shipping to Loki
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 3031;
        grpc_listen_port = 0;
      };
      positions = {
        filename = "/tmp/positions.yaml";
      };
      clients = [{
        url = "http://localhost:3100/loki/api/v1/push";
      }];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }
        {
          job_name = "nginx";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "nginx";
              host = config.networking.hostName;
              __path__ = "/var/log/nginx/*.log";
            };
          }];
        }
      ];
    };
  };

  # System health monitoring script
  systemd.services.health-check = {
    description = "Media server health check";
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      ExecStart = pkgs.writeShellScript "health-check" ''
        #!/usr/bin/env bash
        
        # Check disk space
        DISK_USAGE=$(df /mnt/media | tail -1 | awk '{print $5}' | sed 's/%//')
        if [ "$DISK_USAGE" -gt 90 ]; then
          echo "WARNING: Disk usage at $DISK_USAGE%"
        fi
        
        # Check service status
        SERVICES=("jellyfin" "sonarr" "radarr" "prowlarr" "transmission")
        for service in "''${SERVICES[@]}"; do
          if ! systemctl is-active --quiet "$service"; then
            echo "ERROR: $service is not running"
          fi
        done
        
        # Check media directories
        if [ ! -d "/mnt/media/movies" ] || [ ! -d "/mnt/media/tv" ]; then
          echo "ERROR: Media directories not mounted"
        fi
        
        echo "Health check completed at $(date)"
      '';
    };
  };

  systemd.timers.health-check = {
    description = "Run health check every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };

  # Open monitoring ports
  networking.firewall.allowedTCPPorts = [
    9100  # Node exporter
    3100  # Loki
    3031  # Promtail
  ];
}