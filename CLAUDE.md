# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cistern is a NixOS-based media server fleet management system designed for easy deployment and management of multiple media servers. The project uses a declarative approach with NixOS flakes for reproducible deployments.

## Architecture

### Core Components
- **NixOS Flakes**: Declarative system configurations with dependency management
- **nixos-anywhere**: Remote NixOS installation and initial provisioning
- **deploy-rs**: Ongoing fleet configuration management and updates
- **Modular Configuration**: Separated base system, media services, and hardware configs

### Directory Structure
```
cistern/
├── flake.nix              # Main flake configuration
├── modules/               # Reusable NixOS modules
│   ├── base.nix           # Base system configuration
│   ├── media-server.nix   # Media services (Jellyfin, Sonarr, etc.)
│   └── monitoring.nix     # Prometheus, Loki, health checks
├── hardware/              # Hardware-specific configurations
│   ├── generic.nix        # Standard x86_64 systems
│   └── raspberry-pi.nix   # Raspberry Pi 4/5 support
├── hosts/                 # Individual server configurations
│   └── template.nix       # Template for new servers
├── scripts/               # Management scripts
│   ├── provision.sh       # New server provisioning
│   ├── deploy.sh          # Fleet deployment
│   └── inventory.sh       # Inventory management
└── inventory.yaml         # Fleet inventory and configuration
```

## Essential Commands

### Development Environment
```bash
# Enter development shell with all tools
nix develop

# Check flake configuration
nix flake check
```

### Provisioning New Servers
```bash
# Provision a new server (installs NixOS remotely)
./scripts/provision.sh <hostname/ip> [hardware-type]

# Examples:
./scripts/provision.sh 192.168.1.100
./scripts/provision.sh 192.168.1.101 raspberry-pi
```

### Fleet Management
```bash
# Deploy to entire fleet
./scripts/deploy.sh

# Deploy to specific server
./scripts/deploy.sh media-server-01

# Dry run deployment
./scripts/deploy.sh --dry-run
```

### Inventory Management
```bash
# List all servers
./scripts/inventory.sh list

# Add new server to inventory
./scripts/inventory.sh add media-server-02

# Generate host configurations from inventory
./scripts/inventory.sh generate-hosts
```

### VM Testing
```bash
# Start test VM
./scripts/vm.sh start

# Deploy Cistern to test VM
./scripts/vm.sh deploy

# SSH into test VM
./scripts/vm.sh ssh

# Check VM status
./scripts/vm.sh status

# Stop test VM
./scripts/vm.sh stop

# Reset VM for clean testing
./scripts/vm.sh reset

# Destroy VM and all data
./scripts/vm.sh destroy
```

## Media Services

The system deploys a complete media stack with **automatic configuration**:
- **Jellyfin**: Media server with web interface (auto-configured with Movies & TV libraries)
- **Sonarr**: TV show management (auto-linked to Transmission & Prowlarr)
- **Radarr**: Movie management (auto-linked to Transmission & Prowlarr)
- **Prowlarr**: Indexer management (auto-linked to Sonarr & Radarr)
- **Bazarr**: Subtitle management
- **Transmission**: Torrent client (auto-configured with proper categories)
- **Nginx**: Reverse proxy for all services
- **Dashboard**: Web interface showing all services and status

All services are accessible through a unified web interface on port 80.

### Auto-Configuration Features
- **Pre-configured media libraries**: Jellyfin automatically configured with Movies and TV Shows libraries
- **Service interconnection**: Sonarr and Radarr automatically linked to Transmission for downloads
- **Automatic file sorting**: Downloads automatically sorted into appropriate folders
- **Root folder setup**: Media folders automatically configured in each service
- **User-friendly dashboard**: Simple web interface to access all services

### Manual Configuration Script
For additional customization, use the configuration script:
```bash
./scripts/configure-media.sh [hostname]
```

## Adding New Servers

1. **Add to inventory**: `./scripts/inventory.sh add <server-name>`
2. **Generate host config**: `./scripts/inventory.sh generate-hosts`
3. **Update flake.nix**: Add server to nixosConfigurations and deploy.nodes
4. **Provision**: `./scripts/provision.sh <ip> <hardware-type>`
5. **Deploy**: `./scripts/deploy.sh <server-name>`

## Testing Changes

Before deploying to production servers, test changes in a VM:

1. **Start test VM**: `./scripts/vm.sh start`
2. **Deploy latest Cistern**: `./scripts/vm.sh deploy`
3. **Test services**: Access http://localhost:8080
4. **Verify functionality**: Check logs and service status
5. **Clean up**: `./scripts/vm.sh destroy` when done

## Hardware Support

- **Generic x86_64**: Standard desktop/server hardware
- **Raspberry Pi**: Pi 4/5 with ARM64 support
- **Custom hardware**: Create new configs in `hardware/` directory

## Monitoring

Each server includes:
- **Prometheus node exporter**: System metrics on port 9100
- **Loki**: Log aggregation on port 3100
- **Health checks**: Automated service monitoring
- **System logs**: Centralized via Promtail

## Standard Workflow - YOU MUST ALWAYS FOLLOW
1. First think hard through the problem, read the codebase for relevant files, and write a plan to todo.md.
2. The plan should have a list of todo items that you can check off as you complete them
3. Before you begin working, check in with me and I will verify the plan.
4. Then, begin working on the todo items, marking them as complete as you go.
5. Please every step of the way just give me a high level explanation of what changes you made
6. Make every task and code change you do as simple as possible. We want to avoid making any massive or complex changes. Every change should impact as little code as possible. Everything is about simplicity.
7. Commit changes (don't include that changes were made by Claude code)
8. Finally, add a review section to the todo.md file with a summary of the changes you made and any other relevant information.