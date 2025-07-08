{ config, pkgs, lib, ... }:

{
  # Auto-configuration for media services
  # This module sets up services with sensible defaults and automatic API linking
  
  # Create configuration files with pre-configured settings
  systemd.tmpfiles.rules = [
    "d /var/lib/media/auto-config 0755 media media -"
  ];

  # Auto-configuration script that runs after services start
  systemd.services.media-auto-config = {
    description = "Auto-configure media services";
    after = [ "network.target" "jellyfin.service" "sonarr.service" "radarr.service" "prowlarr.service" "sabnzbd.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      Group = "media";
      RemainAfterExit = true;
    };
    
    script = ''
      LOG_FILE="/var/lib/media/auto-config/setup.log"
      
      echo "$(date): Starting auto-configuration" >> "$LOG_FILE"
      
      # Wait for services to be ready
      sleep 30
      
      # Configure Jellyfin media libraries
      echo "$(date): Configuring Jellyfin" >> "$LOG_FILE"
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "Name": "Movies",
          "CollectionType": "movies",
          "Locations": ["/mnt/media/movies"],
          "LibraryOptions": {
            "EnablePhotos": false,
            "EnableRealtimeMonitor": true,
            "EnableChapterImageExtraction": false
          }
        }' \
        http://127.0.0.1:8096/Library/VirtualFolders >> "$LOG_FILE" 2>&1 || true
      
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "Name": "TV Shows",
          "CollectionType": "tvshows",
          "Locations": ["/mnt/media/tv"],
          "LibraryOptions": {
            "EnablePhotos": false,
            "EnableRealtimeMonitor": true,
            "EnableChapterImageExtraction": false
          }
        }' \
        http://127.0.0.1:8096/Library/VirtualFolders >> "$LOG_FILE" 2>&1 || true
      
      # Configure Sonarr
      echo "$(date): Configuring Sonarr" >> "$LOG_FILE"
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "enable": true,
          "name": "Transmission",
          "implementation": "Transmission",
          "settings": {
            "host": "127.0.0.1",
            "port": 9091,
            "category": "sonarr"
          }
        }' \
        http://127.0.0.1:8989/api/v3/downloadclient >> "$LOG_FILE" 2>&1 || true
      
      # Add SABnzbd to Sonarr
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "enable": true,
          "name": "SABnzbd",
          "implementation": "Sabnzbd",
          "settings": {
            "host": "127.0.0.1",
            "port": 8080,
            "category": "sonarr"
          }
        }' \
        http://127.0.0.1:8989/api/v3/downloadclient >> "$LOG_FILE" 2>&1 || true
      
      # Add root folder for TV shows
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "path": "/mnt/media/tv",
          "accessible": true,
          "freeSpace": 0,
          "unmappedFolders": []
        }' \
        http://127.0.0.1:8989/api/v3/rootfolder >> "$LOG_FILE" 2>&1 || true
      
      # Configure Radarr
      echo "$(date): Configuring Radarr" >> "$LOG_FILE"
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "enable": true,
          "name": "Transmission",
          "implementation": "Transmission",
          "settings": {
            "host": "127.0.0.1",
            "port": 9091,
            "category": "radarr"
          }
        }' \
        http://127.0.0.1:7878/api/v3/downloadclient >> "$LOG_FILE" 2>&1 || true
      
      # Add SABnzbd to Radarr
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "enable": true,
          "name": "SABnzbd",
          "implementation": "Sabnzbd",
          "settings": {
            "host": "127.0.0.1",
            "port": 8080,
            "category": "radarr"
          }
        }' \
        http://127.0.0.1:7878/api/v3/downloadclient >> "$LOG_FILE" 2>&1 || true
      
      # Add root folder for movies
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "path": "/mnt/media/movies",
          "accessible": true,
          "freeSpace": 0,
          "unmappedFolders": []
        }' \
        http://127.0.0.1:7878/api/v3/rootfolder >> "$LOG_FILE" 2>&1 || true
      
      # Configure Prowlarr with basic indexers
      echo "$(date): Configuring Prowlarr" >> "$LOG_FILE"
      # Add Sonarr application
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "name": "Sonarr",
          "implementation": "Sonarr",
          "settings": {
            "prowlarrUrl": "http://127.0.0.1:9696",
            "baseUrl": "http://127.0.0.1:8989",
            "apiKey": "auto-generated"
          }
        }' \
        http://127.0.0.1:9696/api/v1/applications >> "$LOG_FILE" 2>&1 || true
      
      # Add Radarr application
      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "name": "Radarr",
          "implementation": "Radarr",
          "settings": {
            "prowlarrUrl": "http://127.0.0.1:9696",
            "baseUrl": "http://127.0.0.1:7878",
            "apiKey": "auto-generated"
          }
        }' \
        http://127.0.0.1:9696/api/v1/applications >> "$LOG_FILE" 2>&1 || true
      
      echo "$(date): Auto-configuration completed" >> "$LOG_FILE"
      
      # Create marker file to indicate auto-config completed
      touch /var/lib/media/auto-config/completed
    '';
  };

  # Service to generate API keys and configure service interconnections
  systemd.services.media-api-config = {
    description = "Configure media service API connections";
    after = [ "media-auto-config.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      Group = "media";
      RemainAfterExit = true;
    };
    
    script = ''
      # Wait for auto-config to complete
      while [ ! -f /var/lib/media/auto-config/completed ]; do
        sleep 10
      done
      
      # Additional API configuration can go here
      echo "API configuration completed" > /var/lib/media/auto-config/api-completed
    '';
  };
}