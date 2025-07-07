#!/usr/bin/env bash
set -euo pipefail

# Cistern Fleet Inventory Management Script
# This script helps manage the server inventory and generates configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$FLAKE_DIR/inventory.yaml"

show_help() {
    cat << EOF
Cistern Fleet Inventory Management

Usage: $0 <command> [options]

Commands:
    list                List all servers in inventory
    add <name>          Add a new server to inventory
    remove <name>       Remove a server from inventory
    show <name>         Show detailed information about a server
    update <name>       Update server information
    generate-hosts      Generate NixOS host configurations from inventory
    validate            Validate inventory file

Options:
    -h, --help          Show this help message

Examples:
    $0 list
    $0 add media-server-02
    $0 show media-server-01
    $0 generate-hosts

EOF
}

# Check if yq is available
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        echo "Error: yq is required but not installed." >&2
        echo "Install with: nix-env -iA nixpkgs.yq-go" >&2
        exit 1
    fi
}

list_servers() {
    echo "Cistern Media Server Fleet:"
    echo "=========================="
    
    if ! yq e '.servers' "$INVENTORY_FILE" &>/dev/null || [ "$(yq e '.servers | length' "$INVENTORY_FILE")" -eq 0 ]; then
        echo "No servers configured in inventory."
        return
    fi
    
    yq e '.servers | keys | .[]' "$INVENTORY_FILE" | while read -r server; do
        hostname=$(yq e ".servers.${server}.hostname // \"unknown\"" "$INVENTORY_FILE")
        hardware=$(yq e ".servers.${server}.hardware_type // \"unknown\"" "$INVENTORY_FILE")
        role=$(yq e ".servers.${server}.role // \"unknown\"" "$INVENTORY_FILE")
        echo "  $server"
        echo "    Hostname: $hostname"
        echo "    Hardware: $hardware"
        echo "    Role: $role"
        echo
    done
}

show_server() {
    local server_name="$1"
    
    if ! yq e ".servers.$server_name" "$INVENTORY_FILE" &>/dev/null; then
        echo "Error: Server '$server_name' not found in inventory." >&2
        exit 1
    fi
    
    echo "Server: $server_name"
    echo "===================="
    yq e ".servers.$server_name" "$INVENTORY_FILE"
}

add_server() {
    local server_name="$1"
    
    if yq e ".servers.$server_name" "$INVENTORY_FILE" &>/dev/null; then
        echo "Error: Server '$server_name' already exists in inventory." >&2
        exit 1
    fi
    
    echo "Adding new server: $server_name"
    echo
    
    read -p "Hostname/IP: " hostname
    read -p "MAC Address (optional): " mac_address
    read -p "Hardware type [generic]: " hardware_type
    hardware_type=${hardware_type:-generic}
    read -p "Role [primary]: " role
    role=${role:-primary}
    read -p "Location (optional): " location
    read -p "Notes (optional): " notes
    
    # Create temporary config
    temp_config=$(mktemp)
    cat > "$temp_config" << EOF
hostname: "$hostname"
hardware_type: "$hardware_type"
role: "$role"
deployed: "$(date +%Y-%m-%d)"
last_updated: "$(date +%Y-%m-%d)"
services:
  - jellyfin
  - sonarr
  - radarr
  - transmission
EOF
    
    if [ -n "$mac_address" ]; then
        yq e ".mac_address = \"$mac_address\"" -i "$temp_config"
    fi
    
    if [ -n "$location" ]; then
        yq e ".location = \"$location\"" -i "$temp_config"
    fi
    
    if [ -n "$notes" ]; then
        yq e ".notes = \"$notes\"" -i "$temp_config"
    fi
    
    # Add to inventory
    yq e ".servers.$server_name = $(cat "$temp_config")" -i "$INVENTORY_FILE"
    rm "$temp_config"
    
    echo "✅ Server '$server_name' added to inventory"
    echo "Run '$0 generate-hosts' to create NixOS configuration"
}

remove_server() {
    local server_name="$1"
    
    if ! yq e ".servers.$server_name" "$INVENTORY_FILE" &>/dev/null; then
        echo "Error: Server '$server_name' not found in inventory." >&2
        exit 1
    fi
    
    read -p "Are you sure you want to remove '$server_name' from inventory? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    yq e "del(.servers.$server_name)" -i "$INVENTORY_FILE"
    
    # Remove host configuration if it exists
    host_file="$FLAKE_DIR/hosts/$server_name.nix"
    if [ -f "$host_file" ]; then
        rm "$host_file"
        echo "Removed host configuration: $host_file"
    fi
    
    echo "✅ Server '$server_name' removed from inventory"
}

generate_hosts() {
    echo "Generating NixOS host configurations from inventory..."
    
    if ! yq e '.servers' "$INVENTORY_FILE" &>/dev/null || [ "$(yq e '.servers | length' "$INVENTORY_FILE")" -eq 0 ]; then
        echo "No servers in inventory to generate configurations for."
        return
    fi
    
    yq e '.servers | keys | .[]' "$INVENTORY_FILE" | while read -r server; do
        hostname=$(yq e ".servers.${server}.hostname" "$INVENTORY_FILE")
        hardware_type=$(yq e ".servers.${server}.hardware_type" "$INVENTORY_FILE")
        
        host_file="$FLAKE_DIR/hosts/$server.nix"
        
        cat > "$host_file" << EOF
{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix
    ../modules/monitoring.nix
    ../hardware/$hardware_type.nix
  ];

  networking.hostName = "$server";
  
  # Generated from inventory on $(date)
  # Hostname: $hostname
  # Hardware: $hardware_type
  
  system.stateVersion = "24.05";
}
EOF
        
        echo "Generated: $host_file"
    done
    
    echo "✅ Host configurations generated"
    echo "Update flake.nix to include these configurations in nixosConfigurations"
}

validate_inventory() {
    echo "Validating inventory file..."
    
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo "Error: Inventory file not found: $INVENTORY_FILE" >&2
        exit 1
    fi
    
    # Basic YAML validation
    if ! yq e '.' "$INVENTORY_FILE" &>/dev/null; then
        echo "Error: Invalid YAML syntax in inventory file" >&2
        exit 1
    fi
    
    # Check required structure
    if ! yq e '.servers' "$INVENTORY_FILE" &>/dev/null; then
        echo "Warning: No servers section found in inventory"
    fi
    
    echo "✅ Inventory file is valid"
}

# Main script logic
check_dependencies

if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

case "$1" in
    list)
        list_servers
        ;;
    add)
        if [ $# -ne 2 ]; then
            echo "Error: Server name required" >&2
            echo "Usage: $0 add <server-name>" >&2
            exit 1
        fi
        add_server "$2"
        ;;
    remove)
        if [ $# -ne 2 ]; then
            echo "Error: Server name required" >&2
            echo "Usage: $0 remove <server-name>" >&2
            exit 1
        fi
        remove_server "$2"
        ;;
    show)
        if [ $# -ne 2 ]; then
            echo "Error: Server name required" >&2
            echo "Usage: $0 show <server-name>" >&2
            exit 1
        fi
        show_server "$2"
        ;;
    generate-hosts)
        generate_hosts
        ;;
    validate)
        validate_inventory
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo "Error: Unknown command '$1'" >&2
        show_help
        exit 1
        ;;
esac