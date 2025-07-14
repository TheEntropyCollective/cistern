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
    ./nginx.nix
  ];
  
  # Create media group and directories
  users.groups.media = {};
  
  systemd.tmpfiles.rules = [
    "d /var/lib/media 0755 media media -"
    "d /var/lib/media/config 0755 media media -"
    "d /var/lib/media/cache 0755 media media -"
    "d /var/lib/media/scripts 0755 media media -"
    # Create local media directories (fallback when NoiseFS not enabled)
    "d /mnt/media 0755 media media -"
    "d /mnt/media/movies 0755 media media -"
    "d /mnt/media/tv 0755 media media -"
    "d /mnt/media/music 0755 media media -"
    "d /mnt/media/books 0755 media media -"
    "d /mnt/media/downloads 0755 media media -"
    "d /mnt/media/downloads/.incomplete 0755 media media -"
    "d /var/lib/media/config/sabnzbd 0755 media media -"
  ] ++ lib.optionals (config.cistern.auth.enable && config.cistern.auth.method == "authentik") [
    # Jellyfin SSO plugin directories
    "d /var/lib/media/config/jellyfin/plugins 0755 media media -"
    "d /var/lib/media/config/jellyfin/config 0755 media media -"
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

  # Jellyfin SSO plugin configuration (when Authentik is enabled)
  systemd.services.jellyfin-sso-setup = lib.mkIf (config.cistern.auth.enable && config.cistern.auth.method == "authentik") {
    description = "Configure Jellyfin SSO plugin for Authentik";
    after = [ "jellyfin.service" "authentik-server.service" ];
    requires = [ "jellyfin.service" "authentik-server.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      Group = "media";
      RemainAfterExit = true;
    };
    
    script = ''
      JELLYFIN_CONFIG_DIR="/var/lib/media/config/jellyfin"
      PLUGINS_DIR="$JELLYFIN_CONFIG_DIR/plugins"
      SSO_PLUGIN_DIR="$PLUGINS_DIR/SSO Authentication"
      
      # Create plugins directory
      mkdir -p "$SSO_PLUGIN_DIR"
      
      # Download Jellyfin SSO plugin if not exists
      if [ ! -f "$SSO_PLUGIN_DIR/SSO-Authentication.dll" ]; then
        echo "Downloading Jellyfin SSO plugin..."
        ${pkgs.curl}/bin/curl -L -o "/tmp/sso-plugin.zip" \
          "https://github.com/9p4/jellyfin-plugin-sso/releases/latest/download/sso-authentication.zip"
        
        ${pkgs.unzip}/bin/unzip -o "/tmp/sso-plugin.zip" -d "$SSO_PLUGIN_DIR"
        rm -f "/tmp/sso-plugin.zip"
        
        # Set proper permissions
        chown -R media:media "$PLUGINS_DIR"
        
        echo "Jellyfin SSO plugin installed"
      fi
      
      # Create SSO plugin configuration
      SSO_CONFIG_FILE="$JELLYFIN_CONFIG_DIR/config/SSO-Authentication.xml"
      mkdir -p "$(dirname "$SSO_CONFIG_FILE")"
      
      if [ ! -f "$SSO_CONFIG_FILE" ]; then
        cat > "$SSO_CONFIG_FILE" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <SamlConfigs>
    <SamlConfig>
      <SamlEndpoint>https://${config.cistern.auth.authentik.domain}/application/saml/cistern-jellyfin/sso/binding/redirect/</SamlEndpoint>
      <SamlClientId>cistern-jellyfin</SamlClientId>
      <SamlCertificate></SamlCertificate>
      <Enabled>true</Enabled>
      <EnableAuthorization>true</EnableAuthorization>
      <EnableAllFolders>true</EnableAllFolders>
      <EnabledFolders />
      <AdminAttribute>admin</AdminAttribute>
      <LibraryAccessAttribute>library_access</LibraryAccessAttribute>
      <DefaultProvider>Authentik</DefaultProvider>
      <SchemeTypes>
        <string>saml</string>
      </SchemeTypes>
    </SamlConfig>
  </SamlConfigs>
  <OidConfigs>
    <OidConfig>
      <OidEndpoint>https://${config.cistern.auth.authentik.domain}/application/o/cistern-jellyfin/</OidEndpoint>
      <OidClientId>cistern-jellyfin</OidClientId>
      <OidSecret></OidSecret>
      <Enabled>true</Enabled>
      <EnableAuthorization>true</EnableAuthorization>
      <EnableAllFolders>true</EnableAllFolders>
      <EnabledFolders />
      <AdminAttribute>admin</AdminAttribute>
      <LibraryAccessAttribute>library_access</LibraryAccessAttribute>
      <DefaultProvider>Authentik</DefaultProvider>
      <SchemeTypes>
        <string>oid</string>
      </SchemeTypes>
    </OidConfig>
  </OidConfigs>
  <TimerConfig>
    <Enabled>false</Enabled>
    <TimerIntervalHours>24</TimerIntervalHours>
  </TimerConfig>
</PluginConfiguration>
EOF
        
        chown media:media "$SSO_CONFIG_FILE"
        echo "Jellyfin SSO configuration created"
      fi
      
      # Restart Jellyfin to load the plugin
      ${pkgs.systemd}/bin/systemctl restart jellyfin
      
      echo "Jellyfin SSO plugin setup completed"
      echo "Manual configuration steps required:"
      echo "1. Access Jellyfin admin dashboard"
      echo "2. Go to Plugins → SSO Authentication"
      echo "3. Configure Authentik provider settings"
      echo "4. Set up OIDC client secret from Authentik"
    '';
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
    user = "media";
    group = "media";
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
    8081  # Dashboard/IPFS Gateway
    8082  # NoiseFS Web UI
    80    # Nginx
    443   # Nginx HTTPS
    4001  # IPFS Swarm (if NoiseFS enabled)
    5001  # IPFS API (local only)
  ];

  # File system optimizations for media storage
  boot.kernel.sysctl = {
    "vm.dirty_ratio" = 3;
    "vm.dirty_background_ratio" = 2;
    "vm.vfs_cache_pressure" = 50;
  };
}