#!/usr/bin/env bash
set -euo pipefail

# Smart deployment script that auto-detects disk device
# Usage: ./scripts/deploy-smart.sh <target-ip>

TARGET_IP=${1:-192.168.1.244}
SSH_KEY="$HOME/.ssh/cistern_deploy"

echo "Smart nixos-anywhere deployment to $TARGET_IP"
echo "This script will auto-detect the disk device and configure accordingly"
echo ""

# Check if SSH key exists
if [[ ! -f "$SSH_KEY" ]]; then
    echo "Creating SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "cistern-deploy"
fi

# Copy SSH key if needed
if ! ssh -i "$SSH_KEY" -o PasswordAuthentication=no nixos@$TARGET_IP "echo 'SSH key works'" 2>/dev/null; then
    echo "Copying SSH key to target..."
    echo "You'll need to enter the password 'test123'"
    ssh-copy-id -i "$SSH_KEY.pub" -o PreferredAuthentications=password nixos@$TARGET_IP
fi

# Auto-detect disk device
echo "Detecting disk device on target system..."
DISK_INFO=$(ssh -i "$SSH_KEY" nixos@$TARGET_IP "lsblk -d -n -o NAME,SIZE,TYPE | grep disk")
echo "Available disks:"
echo "$DISK_INFO"
echo ""

# Try to determine the main disk device
MAIN_DISK=""
if echo "$DISK_INFO" | grep -q "^vda "; then
    MAIN_DISK="vda"
    DISK_CONFIG="disk-configs/vda.nix"
elif echo "$DISK_INFO" | grep -q "^sda "; then
    MAIN_DISK="sda"
    DISK_CONFIG="disk-configs/sda.nix"
elif echo "$DISK_INFO" | grep -q "^nvme0n1 "; then
    MAIN_DISK="nvme0n1"
    DISK_CONFIG="disk-configs/nvme.nix"
else
    echo "Could not auto-detect main disk device. Please check the output above."
    echo "Common devices: vda (VM), sda (SATA), nvme0n1 (NVMe)"
    exit 1
fi

echo "Detected main disk: /dev/$MAIN_DISK"
echo "Using disk configuration: $DISK_CONFIG"

# Update the deploy-test configuration to use the detected disk config
echo "Updating deploy-test configuration..."
sed -i.bak "s|../disk-config.nix|../$DISK_CONFIG|" hosts/deploy-test.nix

# Run nixos-anywhere
echo "Running nixos-anywhere..."
nixos-anywhere \
  --flake .#deploy-test \
  --build-on remote \
  -i "$SSH_KEY" \
  nixos@$TARGET_IP

# Restore original configuration
echo "Restoring original configuration..."
mv hosts/deploy-test.nix.bak hosts/deploy-test.nix

echo "Deployment complete!"
echo "Access your Cistern server at: http://$TARGET_IP"
echo "Login with username: test, password: test123"