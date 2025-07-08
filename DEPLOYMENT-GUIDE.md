# Cistern Deployment Guide

Complete guide for deploying Cistern media server with dual torrent/Usenet support.

## Quick Start

### 1. Provision New Server
```bash
# For new hardware installation
./scripts/provision.sh <server-ip> [hardware-type]

# Examples:
./scripts/provision.sh 192.168.1.100
./scripts/provision.sh 192.168.1.101 raspberry-pi
```

### 2. Access Your Media Server
After deployment completes (5-10 minutes):
- **Main Dashboard**: `http://your-server/`
- **Jellyfin**: `http://your-server:8096`
- **All services** accessible through dashboard

### 3. Initial Configuration
1. **Verify Services**: Visit dashboard to confirm all services are running
2. **Configure Usenet**: Add your Usenet provider in SABnzbd
3. **Add Indexers**: Configure torrent and Usenet indexers in Prowlarr
4. **Start Adding Content**: Use Sonarr and Radarr to manage your media

## What Gets Installed

### Core Media Stack
- **Jellyfin**: Media server with Movies & TV libraries pre-configured
- **Sonarr**: TV show management with automatic download client integration
- **Radarr**: Movie management with automatic download client integration
- **Prowlarr**: Indexer management for both torrent and Usenet sources
- **Bazarr**: Subtitle management for all content

### Download Clients (Dual Support)
- **Transmission**: Torrent client with automatic categorization
- **SABnzbd**: Usenet client with automatic categorization
- **Both clients** automatically configured in Sonarr and Radarr

### Infrastructure
- **Nginx**: Reverse proxy for unified web access
- **Prometheus + Loki**: Monitoring and logging
- **Auto-configuration**: All services pre-connected and ready to use

## Service Access URLs

| Service | Direct Access | Reverse Proxy |
|---------|---------------|---------------|
| Dashboard | `http://server:8081` | `http://server/dashboard` |
| Jellyfin | `http://server:8096` | `http://server/` |
| Sonarr | `http://server:8989` | `http://server/sonarr` |
| Radarr | `http://server:7878` | `http://server/radarr` |
| Prowlarr | `http://server:9696` | `http://server/prowlarr` |
| Bazarr | `http://server:6767` | `http://server/bazarr` |
| Transmission | `http://server:9091` | `http://server/transmission` |
| SABnzbd | `http://server:8080` | `http://server/sabnzbd` |

## Post-Deployment Setup

### 1. SABnzbd Usenet Configuration
1. Navigate to `http://your-server:8080`
2. Go to **Settings → Servers**
3. Add your Usenet provider:
   - **Host**: Your provider's server (e.g., `news.provider.com`)
   - **Port**: SSL port (usually 563 or 443)
   - **Username/Password**: Your account credentials
   - **Connections**: Start with 10-20
   - **SSL**: Enable for security

Popular Usenet providers:
- **Eweka**: High-speed European provider
- **Newsgroup Ninja**: US-based with good retention
- **UsenetServer**: Global provider with backbone access

### 2. Prowlarr Indexer Setup
1. Navigate to `http://your-server:9696`
2. Add **Torrent Indexers**:
   - Public: RARBG, 1337x, ThePirateBay
   - Private: Add your tracker credentials
3. Add **Usenet Indexers**:
   - NZBgeek, NZBplanet, DrunkenSlug
   - Configure API keys from indexer websites

### 3. Verify Auto-Configuration
Check that download clients are properly configured:

**In Sonarr** (`http://your-server:8989`):
- Go to **Settings → Download Clients**
- Verify both "Transmission" and "SABnzbd" are listed and enabled

**In Radarr** (`http://your-server:7878`):
- Go to **Settings → Download Clients** 
- Verify both "Transmission" and "SABnzbd" are listed and enabled

### 4. Test the System
1. **Add a TV Show** in Sonarr
2. **Add a Movie** in Radarr
3. **Monitor Downloads** in Transmission and SABnzbd
4. **Check Jellyfin** for new content after downloads complete

## Directory Structure

All media is organized in `/mnt/media/`:
```
/mnt/media/
├── movies/          # Movie files (Radarr → Jellyfin)
├── tv/              # TV show files (Sonarr → Jellyfin)
├── music/           # Music files (future expansion)
├── books/           # Book files (future expansion)
└── downloads/       # Active downloads
    └── .incomplete  # Incomplete downloads
```

## Auto-Configuration Details

Cistern automatically configures:
- **Media Libraries**: Jellyfin Movies and TV Shows libraries
- **Download Categories**: Proper categorization for Sonarr/Radarr
- **Root Folders**: `/mnt/media/movies` and `/mnt/media/tv`
- **Service Connections**: All APIs and integrations between services
- **File Permissions**: Proper ownership under `media` user
- **Reverse Proxy**: Nginx routes for all services

## Troubleshooting

### Services Not Starting
Check service status:
```bash
ssh root@your-server
systemctl status jellyfin sonarr radarr sabnzbd transmission
```

### Auto-Configuration Issues
Check setup logs:
```bash
ssh root@your-server
cat /var/lib/media/auto-config/setup.log
```

### Network Access Issues
Verify firewall ports are open:
```bash
ssh root@your-server
systemctl status firewall
```

### Download Client Issues
1. **Transmission**: Check web interface at `:9091`
2. **SABnzbd**: Verify Usenet provider configuration
3. **Both**: Ensure download directories have proper permissions

## Advanced Configuration

### Adding More Servers
```bash
# Add new server to inventory
./scripts/inventory.sh add media-server-02

# Generate host configurations
./scripts/inventory.sh generate-hosts

# Update flake.nix with new server
# Deploy to new server
./scripts/provision.sh <new-server-ip>
```

### Fleet Management
```bash
# Deploy to entire fleet
./scripts/deploy.sh

# Deploy to specific server
./scripts/deploy.sh media-server-01
```

### Monitoring
- **Prometheus**: `http://server:9090`
- **Node Exporter**: `http://server:9100`
- **Loki**: `http://server:3100`

## Security Notes

- **Default Config**: Services are configured for local network access
- **Firewall**: Only necessary ports are opened
- **User Isolation**: All media services run under dedicated `media` user
- **No Default Passwords**: Configure authentication as needed
- **SSL**: Enable HTTPS in nginx for external access

## Support

For issues:
1. Check service logs: `journalctl -u <service-name>`
2. Review auto-configuration logs: `/var/lib/media/auto-config/setup.log`
3. Verify network connectivity between services
4. Check Cistern documentation: `CLAUDE.md`

## Success Indicators

Your deployment is successful when:
- ✅ Dashboard shows all services as "Ready"
- ✅ Jellyfin displays Movies and TV Shows libraries
- ✅ Sonarr shows both Transmission and SABnzbd download clients
- ✅ Radarr shows both Transmission and SABnzbd download clients
- ✅ SABnzbd connects to your Usenet provider
- ✅ Prowlarr has indexers configured
- ✅ You can search and download content automatically

Enjoy your fully automated media server with dual torrent/Usenet support!