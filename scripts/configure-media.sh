#!/bin/bash

# Media Server Configuration Script
# This script helps users configure their media server with minimal input

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
MEDIA_SERVER=${1:-"localhost"}
TIMEOUT=300

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

wait_for_service() {
    local service_name=$1
    local port=$2
    local max_wait=$3
    
    log "Waiting for $service_name to be ready on port $port..."
    
    local count=0
    while ! nc -z "$MEDIA_SERVER" "$port" 2>/dev/null; do
        if [ $count -ge $max_wait ]; then
            error "$service_name is not responding after ${max_wait}s"
            return 1
        fi
        sleep 1
        ((count++))
    done
    
    log "$service_name is ready!"
    return 0
}

configure_jellyfin() {
    log "Configuring Jellyfin media libraries..."
    
    # Create Movies library
    curl -s -X POST \
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
        "http://$MEDIA_SERVER:8096/Library/VirtualFolders" || warn "Failed to create Movies library"
    
    # Create TV Shows library
    curl -s -X POST \
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
        "http://$MEDIA_SERVER:8096/Library/VirtualFolders" || warn "Failed to create TV Shows library"
    
    log "Jellyfin configuration complete!"
}

configure_sonarr() {
    log "Configuring Sonarr..."
    
    # Add Transmission download client
    curl -s -X POST \
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
        "http://$MEDIA_SERVER:8989/api/v3/downloadclient" || warn "Failed to add Transmission to Sonarr"
    
    # Add root folder
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "path": "/mnt/media/tv",
            "accessible": true,
            "freeSpace": 0,
            "unmappedFolders": []
        }' \
        "http://$MEDIA_SERVER:8989/api/v3/rootfolder" || warn "Failed to add root folder to Sonarr"
    
    log "Sonarr configuration complete!"
}

configure_radarr() {
    log "Configuring Radarr..."
    
    # Add Transmission download client
    curl -s -X POST \
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
        "http://$MEDIA_SERVER:7878/api/v3/downloadclient" || warn "Failed to add Transmission to Radarr"
    
    # Add root folder
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "path": "/mnt/media/movies",
            "accessible": true,
            "freeSpace": 0,
            "unmappedFolders": []
        }' \
        "http://$MEDIA_SERVER:7878/api/v3/rootfolder" || warn "Failed to add root folder to Radarr"
    
    log "Radarr configuration complete!"
}

show_access_info() {
    log "Media server configuration complete!"
    echo ""
    echo "Access your services at:"
    echo "  Jellyfin (Media Server): http://$MEDIA_SERVER:8096"
    echo "  Sonarr (TV Shows):       http://$MEDIA_SERVER:8989"
    echo "  Radarr (Movies):         http://$MEDIA_SERVER:7878"
    echo "  Prowlarr (Indexers):     http://$MEDIA_SERVER:9696"
    echo "  Bazarr (Subtitles):      http://$MEDIA_SERVER:6767"
    echo "  Transmission (Downloads): http://$MEDIA_SERVER:9091"
    echo ""
    echo "  Or access everything through the unified interface:"
    echo "  http://$MEDIA_SERVER"
    echo ""
    log "Your media server is ready to use!"
}

main() {
    log "Starting media server configuration..."
    
    # Check if netcat is available
    if ! command -v nc &> /dev/null; then
        error "netcat (nc) is required but not installed"
        exit 1
    fi
    
    # Wait for services to be ready
    wait_for_service "Jellyfin" 8096 60
    wait_for_service "Sonarr" 8989 60
    wait_for_service "Radarr" 7878 60
    wait_for_service "Prowlarr" 9696 60
    wait_for_service "Transmission" 9091 60
    
    # Configure services
    configure_jellyfin
    configure_sonarr
    configure_radarr
    
    # Show access information
    show_access_info
}

# Run main function
main "$@"