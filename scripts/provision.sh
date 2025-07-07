#!/usr/bin/env bash
set -euo pipefail

# Cistern Media Server Provisioning Script
# This script uses nixos-anywhere to install NixOS on remote machines

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

show_help() {
    cat << EOF
Cistern Media Server Provisioning

Usage: $0 [OPTIONS] <hostname/ip> [hardware-type]

Arguments:
    hostname/ip     Target machine hostname or IP address
    hardware-type   Hardware configuration (default: generic)
                   Options: generic, raspberry-pi

Options:
    -h, --help      Show this help message
    -k, --ssh-key   SSH private key file (default: ~/.ssh/id_rsa)
    -u, --user      SSH user (default: root)
    -p, --port      SSH port (default: 22)
    -n, --dry-run   Show what would be done without executing
    --build-local   Build on local machine instead of remote

Examples:
    $0 192.168.1.100
    $0 192.168.1.101 raspberry-pi
    $0 media-server.local generic --ssh-key ~/.ssh/deploy_key

EOF
}

# Default values
SSH_KEY="$HOME/.ssh/id_rsa"
SSH_USER="root"
SSH_PORT="22"
HARDWARE_TYPE="generic"
DRY_RUN=false
BUILD_LOCAL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -k|--ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        -u|--user)
            SSH_USER="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --build-local)
            BUILD_LOCAL=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
        *)
            if [ -z "${TARGET_HOST:-}" ]; then
                TARGET_HOST="$1"
            elif [ -z "${HARDWARE_TYPE_ARG:-}" ]; then
                HARDWARE_TYPE_ARG="$1"
                HARDWARE_TYPE="$1"
            else
                echo "Too many arguments" >&2
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "${TARGET_HOST:-}" ]; then
    echo "Error: hostname/ip is required" >&2
    show_help
    exit 1
fi

# Validate SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key file not found: $SSH_KEY" >&2
    exit 1
fi

# Create flake configuration for this specific deployment
TEMP_FLAKE_DIR=$(mktemp -d)
trap "rm -rf $TEMP_FLAKE_DIR" EXIT

echo "Setting up deployment configuration..."

# Copy base flake
cp -r "$FLAKE_DIR"/* "$TEMP_FLAKE_DIR/"

# Create host-specific configuration
HOST_CONFIG="$TEMP_FLAKE_DIR/hosts/deploy-target.nix"
cat > "$HOST_CONFIG" << EOF
{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix
    ../modules/monitoring.nix
    ../hardware/${HARDWARE_TYPE}.nix
  ];

  networking.hostName = "media-server-$(date +%s)";
  
  # Auto-generate host ID
  networking.hostId = "$(head -c4 /dev/urandom | od -A none -t x4 | tr -d ' ')";

  system.stateVersion = "24.05";
}
EOF

# Update flake.nix to include the deploy target
sed -i.bak 's/media-server-template/deploy-target/g' "$TEMP_FLAKE_DIR/flake.nix"

# Build nixos-anywhere command
NIXOS_ANYWHERE_CMD=(
    nixos-anywhere
    --flake ".#deploy-target"
)

if [ "$BUILD_LOCAL" = true ]; then
    NIXOS_ANYWHERE_CMD+=(--build-on-remote)
fi

NIXOS_ANYWHERE_CMD+=(
    --ssh-option "IdentityFile=$SSH_KEY"
    --ssh-option "Port=$SSH_PORT"
    "$SSH_USER@$TARGET_HOST"
)

echo "Provisioning media server..."
echo "Target: $TARGET_HOST"
echo "Hardware: $HARDWARE_TYPE"
echo "SSH Key: $SSH_KEY"
echo "SSH User: $SSH_USER"
echo "SSH Port: $SSH_PORT"
echo

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN - Would execute:"
    echo "cd $TEMP_FLAKE_DIR && ${NIXOS_ANYWHERE_CMD[*]}"
    exit 0
fi

# Change to temp directory and execute
cd "$TEMP_FLAKE_DIR"

echo "Executing nixos-anywhere..."
"${NIXOS_ANYWHERE_CMD[@]}"

echo
echo "✅ Provisioning completed successfully!"
echo "Your media server should now be running at: http://$TARGET_HOST"
echo
echo "Next steps:"
echo "1. Add this server to your fleet configuration"
echo "2. Configure storage mounts in the host configuration"
echo "3. Set up media libraries in Jellyfin"