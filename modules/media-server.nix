{ config, pkgs, lib, ... }:

{
  # Media server configuration for Cistern fleet
  
  # Import additional modules for auto-configuration
  imports = [
    ./auto-config.nix
    ./media-scripts.nix
    ./web-dashboard.nix
    ./auth.nix
    ./ssl.nix
  ];
  
  # Create media group and directories
  users.groups.media = {};
  
  systemd.tmpfiles.rules = [
    "d /var/lib/media 0755 media media -"
    "d /var/lib/media/config 0755 media media -"
    "d /var/lib/media/cache 0755 media media -"
    "d /var/lib/media/scripts 0755 media media -"
    "d /mnt/media 0755 media media -"
    "d /mnt/media/movies 0755 media media -"
    "d /mnt/media/tv 0755 media media -"
    "d /mnt/media/music 0755 media media -"
    "d /mnt/media/books 0755 media media -"
    "d /mnt/media/downloads 0755 media media -"
    "d /mnt/media/downloads/.incomplete 0755 media media -"
    "d /var/lib/media/config/sabnzbd 0755 media media -"
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
      
      # Privacy-focused settings
      encryption = 2;  # Require encryption
      dht-enabled = false;  # Disable DHT for privacy
      lpd-enabled = false;  # Disable Local Peer Discovery  
      pex-enabled = false;  # Disable Peer Exchange
      peer-port-random-on-start = true;  # Randomize port
      
      # Connection limits for privacy
      peer-limit-global = 50;
      peer-limit-per-torrent = 10;
      
      # Pre-configure categories for automatic sorting
      script-torrent-done-enabled = true;
      script-torrent-done-filename = "/var/lib/media/scripts/torrent-done.sh";
    };
  };

  # SABnzbd for Usenet management
  services.sabnzbd = {
    enable = true;
    openFirewall = true;
    user = "media";
    group = "media";
    configFile = "/var/lib/media/config/sabnzbd";
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

  # Nginx configuration is provided by auth.nix module
  # Basic nginx setup for services that don't require auth
  services.nginx.enable = lib.mkDefault true;

  # Open firewall ports for media services
  networking.firewall.allowedTCPPorts = [
    8096  # Jellyfin
    8920  # Jellyfin HTTPS
    7878  # Radarr
    8989  # Sonarr
    9696  # Prowlarr
    6767  # Bazarr
    9091  # Transmission
    8080  # SABnzbd
    8081  # Dashboard
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