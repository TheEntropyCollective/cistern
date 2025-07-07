{ config, pkgs, lib, ... }:

{
  # Media server configuration for Cistern fleet
  
  # Create media group and directories
  users.groups.media = {};
  
  systemd.tmpfiles.rules = [
    "d /var/lib/media 0755 media media -"
    "d /var/lib/media/config 0755 media media -"
    "d /var/lib/media/cache 0755 media media -"
    "d /mnt/media 0755 media media -"
    "d /mnt/media/movies 0755 media media -"
    "d /mnt/media/tv 0755 media media -"
    "d /mnt/media/music 0755 media media -"
    "d /mnt/media/books 0755 media media -"
  ];

  # Jellyfin media server
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "media";
    group = "media";
    dataDir = "/var/lib/media/config/jellyfin";
    cacheDir = "/var/lib/media/cache/jellyfin";
  };

  # Additional media server options (uncomment as needed)
  
  # Plex alternative (disable jellyfin if using this)
  # services.plex = {
  #   enable = true;
  #   openFirewall = true;
  #   user = "media";
  #   group = "media";
  #   dataDir = "/var/lib/media/config/plex";
  # };

  # Transmission for torrent management
  services.transmission = {
    enable = true;
    openFirewall = true;
    user = "media";
    group = "media";
    home = "/var/lib/media/config/transmission";
    settings = {
      download-dir = "/mnt/media/downloads";
      incomplete-dir = "/mnt/media/downloads/.incomplete";
      rpc-bind-address = "0.0.0.0";
      rpc-whitelist = "127.0.0.1,192.168.*.*,10.*.*.*";
      rpc-host-whitelist-enabled = false;
      ratio-limit-enabled = true;
      ratio-limit = 2.0;
    };
  };

  # Sonarr for TV show management
  services.sonarr = {
    enable = true;
    openFirewall = true;
    user = "media";
    group = "media";
    dataDir = "/var/lib/media/config/sonarr";
  };

  # Radarr for movie management
  services.radarr = {
    enable = true;
    openFirewall = true;
    user = "media";
    group = "media";
    dataDir = "/var/lib/media/config/radarr";
  };

  # Prowlarr for indexer management
  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  # Bazarr for subtitle management
  services.bazarr = {
    enable = true;
    openFirewall = true;
    user = "media";
    group = "media";
  };

  # Nginx reverse proxy for web services
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    
    virtualHosts = {
      # Main media server interface
      "${config.networking.hostName}.local" = {
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:8096";
            proxyWebsockets = true;
          };
          "/sonarr" = {
            proxyPass = "http://127.0.0.1:8989";
            proxyWebsockets = true;
          };
          "/radarr" = {
            proxyPass = "http://127.0.0.1:7878";
            proxyWebsockets = true;
          };
          "/prowlarr" = {
            proxyPass = "http://127.0.0.1:9696";
            proxyWebsockets = true;
          };
          "/bazarr" = {
            proxyPass = "http://127.0.0.1:6767";
            proxyWebsockets = true;
          };
          "/transmission" = {
            proxyPass = "http://127.0.0.1:9091";
            proxyWebsockets = true;
          };
        };
      };
    };
  };

  # Open firewall ports for media services
  networking.firewall.allowedTCPPorts = [
    8096  # Jellyfin
    8920  # Jellyfin HTTPS
    7878  # Radarr
    8989  # Sonarr
    9696  # Prowlarr
    6767  # Bazarr
    9091  # Transmission
    80    # Nginx
    443   # Nginx HTTPS
  ];

  # File system optimizations for media storage
  boot.kernel.sysctl = {
    "vm.dirty_ratio" = 3;
    "vm.dirty_background_ratio" = 2;
    "vm.vfs_cache_pressure" = 50;
  };
}