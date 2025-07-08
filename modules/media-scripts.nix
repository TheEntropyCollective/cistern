{ config, pkgs, lib, ... }:

{
  # Media management scripts
  
  # Create torrent completion script
  systemd.tmpfiles.rules = [
    "L+ /var/lib/media/scripts/torrent-done.sh 0755 media media - ${pkgs.writeScript "torrent-done.sh" ''
      #!/bin/bash
      # Torrent completion script for automatic sorting
      
      # Environment variables from Transmission:
      # TR_TORRENT_NAME - torrent name
      # TR_TORRENT_DIR - download directory
      # TR_TORRENT_HASH - torrent hash
      
      LOG_FILE="/var/lib/media/scripts/torrent-done.log"
      
      echo "$(date): Processing torrent: $TR_TORRENT_NAME" >> "$LOG_FILE"
      
      # Basic file sorting based on file extension
      if [[ "$TR_TORRENT_NAME" =~ \.(mkv|mp4|avi|m4v)$ ]]; then
        # Video files - determine if TV or Movie
        if [[ "$TR_TORRENT_NAME" =~ [Ss][0-9]+[Ee][0-9]+ ]]; then
          # TV Show pattern detected
          echo "$(date): Moving TV show: $TR_TORRENT_NAME" >> "$LOG_FILE"
          mkdir -p "/mnt/media/tv/$(basename "$TR_TORRENT_NAME" | cut -d'.' -f1)"
          mv "$TR_TORRENT_DIR/$TR_TORRENT_NAME" "/mnt/media/tv/"
        else
          # Movie
          echo "$(date): Moving movie: $TR_TORRENT_NAME" >> "$LOG_FILE"
          mv "$TR_TORRENT_DIR/$TR_TORRENT_NAME" "/mnt/media/movies/"
        fi
      fi
      
      echo "$(date): Finished processing: $TR_TORRENT_NAME" >> "$LOG_FILE"
    ''}"
  ];

  # Service configuration script
  systemd.tmpfiles.rules = [
    "L+ /var/lib/media/scripts/configure-services.sh 0755 media media - ${pkgs.writeScript "configure-services.sh" ''
      #!/bin/bash
      # Auto-configure media services with sensible defaults
      
      LOG_FILE="/var/lib/media/scripts/config.log"
      
      echo "$(date): Starting service configuration" >> "$LOG_FILE"
      
      # Wait for services to be ready
      sleep 30
      
      # Configure Jellyfin library paths
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
        http://127.0.0.1:8096/Library/VirtualFolders || true
      
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
        http://127.0.0.1:8096/Library/VirtualFolders || true
      
      echo "$(date): Service configuration completed" >> "$LOG_FILE"
    ''}"
  ];
}