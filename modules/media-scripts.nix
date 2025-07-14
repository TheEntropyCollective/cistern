{ config, pkgs, lib, ... }:

{
  # Media management scripts
  
  # Create media management scripts
  systemd.tmpfiles.rules = [
    "L+ /var/lib/media/scripts/torrent-done.sh 0755 media media - ${pkgs.writeScript "torrent-done.sh" ''
      #!/bin/bash
      # Torrent completion script for automatic sorting
      
      # Environment variables from Transmission:
      # TR_TORRENT_NAME - torrent name
      # TR_TORRENT_DIR - download directory
      # TR_TORRENT_HASH - torrent hash
      
      LOG_FILE="/var/lib/media/scripts/torrent-done.log"
      
      # Sanitization function to prevent command injection
      sanitize_filename() {
        local input="$1"
        # Remove directory traversal attempts
        local sanitized="''${input//\.\.}"
        # Remove shell metacharacters and control characters
        # Allow only alphanumeric, dots, dashes, underscores, spaces, and brackets
        sanitized=$(echo "$sanitized" | tr -cd '[:alnum:]._- []')
        # Remove leading/trailing spaces and dots
        sanitized="''${sanitized#"''${sanitized%%[![:space:]]*}"}"
        sanitized="''${sanitized%"''${sanitized##*[![:space:]]}"}"
        sanitized="''${sanitized#.}"
        sanitized="''${sanitized%.}"
        echo "$sanitized"
      }
      
      # Sanitize all input variables
      SAFE_TORRENT_NAME=$(sanitize_filename "$TR_TORRENT_NAME")
      SAFE_TORRENT_DIR=$(sanitize_filename "$TR_TORRENT_DIR")
      
      # Log both original and sanitized values for debugging
      echo "$(date): Original torrent name: $TR_TORRENT_NAME" >> "$LOG_FILE"
      echo "$(date): Sanitized torrent name: $SAFE_TORRENT_NAME" >> "$LOG_FILE"
      
      # Validate that sanitized name is not empty
      if [[ -z "$SAFE_TORRENT_NAME" ]]; then
        echo "$(date): ERROR: Torrent name became empty after sanitization" >> "$LOG_FILE"
        exit 1
      fi
      
      echo "$(date): Processing torrent: $SAFE_TORRENT_NAME" >> "$LOG_FILE"
      
      # Basic file sorting based on file extension
      if [[ "$SAFE_TORRENT_NAME" =~ \.(mkv|mp4|avi|m4v)$ ]]; then
        # Video files - determine if TV or Movie
        if [[ "$SAFE_TORRENT_NAME" =~ [Ss][0-9]+[Ee][0-9]+ ]]; then
          # TV Show pattern detected
          echo "$(date): Moving TV show: $SAFE_TORRENT_NAME" >> "$LOG_FILE"
          # Extract show name safely
          SHOW_NAME=$(echo "$SAFE_TORRENT_NAME" | cut -d'.' -f1)
          SAFE_SHOW_NAME=$(sanitize_filename "$SHOW_NAME")
          
          # Create directory with proper quoting
          mkdir -p "/mnt/media/tv/''${SAFE_SHOW_NAME}"
          
          # Move file with proper quoting to prevent injection
          if [[ -e "$TR_TORRENT_DIR/$TR_TORRENT_NAME" ]]; then
            mv -- "$TR_TORRENT_DIR/$TR_TORRENT_NAME" "/mnt/media/tv/"
          else
            echo "$(date): ERROR: Source file not found: $TR_TORRENT_DIR/$TR_TORRENT_NAME" >> "$LOG_FILE"
          fi
        else
          # Movie
          echo "$(date): Moving movie: $SAFE_TORRENT_NAME" >> "$LOG_FILE"
          
          # Move file with proper quoting to prevent injection
          if [[ -e "$TR_TORRENT_DIR/$TR_TORRENT_NAME" ]]; then
            mv -- "$TR_TORRENT_DIR/$TR_TORRENT_NAME" "/mnt/media/movies/"
          else
            echo "$(date): ERROR: Source file not found: $TR_TORRENT_DIR/$TR_TORRENT_NAME" >> "$LOG_FILE"
          fi
        fi
      fi
      
      echo "$(date): Finished processing: $SAFE_TORRENT_NAME" >> "$LOG_FILE"
    ''}"
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