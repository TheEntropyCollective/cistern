#!/usr/bin/env bash
set -euo pipefail

# Partition the disk
parted /dev/vda --script mklabel msdos
parted /dev/vda --script mkpart primary ext4 1MiB 100%

# Format the partition
mkfs.ext4 -L nixos /dev/vda1

# Mount the partition
mount /dev/vda1 /mnt

# Generate basic configuration
nixos-generate-config --root /mnt

# Install NixOS
nixos-install --no-root-passwd

echo "NixOS installation complete!"
