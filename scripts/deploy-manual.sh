#!/usr/bin/env bash
set -euo pipefail

# Manual deployment script for nixos-anywhere when SSH is working
# Usage: ./scripts/deploy-manual.sh <target-ip>

TARGET_IP=${1:-192.168.1.244}
SSH_KEY="$HOME/.ssh/cistern_deploy"

echo "Manual nixos-anywhere deployment to $TARGET_IP"
echo "Make sure you can SSH manually first: ssh -i $SSH_KEY nixos@$TARGET_IP"
echo ""

# Check if SSH key exists
if [[ ! -f "$SSH_KEY" ]]; then
    echo "Creating SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "cistern-deploy"
fi

# Copy SSH key (this will require password)
echo "Copying SSH key to target..."
echo "You'll need to enter the password 'test123'"
ssh-copy-id -i "$SSH_KEY.pub" -o PreferredAuthentications=password nixos@$TARGET_IP

# Run nixos-anywhere with the SSH key
echo "Running nixos-anywhere..."
nixos-anywhere \
  --flake .#deploy-test \
  --build-on remote \
  -i "$SSH_KEY" \
  nixos@$TARGET_IP

echo "Deployment complete!"
echo "Access your Cistern server at: http://$TARGET_IP"
echo "Login with username: test, password: test123"