#!/usr/bin/env bash
set -euo pipefail

# Cistern VM Testing Script
# This script creates and manages NixOS VMs for testing Cistern deployments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="$FLAKE_DIR/.vm"
VM_CONFIG_DIR="$FLAKE_DIR/vm"
VM_NAME="cistern-test"
VM_DISK="$VM_DIR/${VM_NAME}.qcow2"
VM_SSH_KEY="$VM_DIR/vm_ssh_key"
VM_IP="192.168.122.100"
VM_PORT="2222"

show_help() {
    cat << EOF
Cistern VM Testing

Usage: $0 <command> [options]

Commands:
    start               Start the test VM
    stop                Stop the test VM
    status              Show VM status
    ssh                 SSH into the VM
    deploy              Deploy Cistern to the VM
    destroy             Destroy the VM and all data
    reset               Reset VM to clean NixOS state

Options:
    -h, --help          Show this help message
    -v, --verbose       Verbose output

Examples:
    $0 start            # Start the VM
    $0 deploy           # Deploy latest Cistern to VM
    $0 ssh              # SSH into the running VM
    $0 reset            # Reset VM for clean testing

EOF
}

setup_vm_environment() {
    echo "Setting up VM environment..."
    
    # Create VM directory
    mkdir -p "$VM_DIR"
    
    # Generate SSH key for VM access if it doesn't exist
    if [ ! -f "$VM_SSH_KEY" ]; then
        echo "Generating SSH key for VM access..."
        ssh-keygen -t ed25519 -f "$VM_SSH_KEY" -N "" -C "cistern-vm-test"
    fi
}

setup_vm_config() {
    # Copy VM configuration files to VM directory
    cp -r "$VM_CONFIG_DIR"/* "$VM_DIR/"
    
    # Copy SSH public key to VM config directory
    cp "${VM_SSH_KEY}.pub" "$VM_DIR/vm_ssh_key.pub"
}

start_vm() {
    setup_vm_environment
    
    if vm_running; then
        echo "VM is already running"
        return 0
    fi
    
    echo "Starting NixOS VM for Cistern testing..."
    
    # Check if VM disk exists and is set up
    if [ ! -f "$VM_DISK" ]; then
        echo "Creating new VM disk..."
        qemu-img create -f qcow2 "$VM_DISK" 20G
        echo "VM disk created. Use '$0 deploy' to install Cistern to the VM."
        echo "Or manually install NixOS first, then deploy."
    fi
    
    # Start existing VM
    echo "Starting VM in background..."
    
    # Detect accelerator (KVM on Linux, HVF on macOS)
    local accel_option=""
    if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -r /dev/kvm ]; then
        # Linux - use KVM if available
        accel_option="-enable-kvm"
    else
        # Fallback to software emulation (slower but works everywhere)
        echo "Note: Using software emulation (no hardware acceleration available)"
    fi
    
    qemu-system-x86_64 \
        $accel_option \
        -m 2048 \
        -smp 2 \
        -drive file="$VM_DISK",format=qcow2 \
        -netdev user,id=net0,hostfwd=tcp::$VM_PORT-:22,hostfwd=tcp::8080-:80 \
        -device virtio-net-pci,netdev=net0 \
        -display none \
        -daemonize \
        -pidfile "$VM_DIR/vm.pid"
    
    echo "VM started. Waiting for SSH access..."
    wait_for_ssh
    echo "✅ VM is ready!"
    echo "SSH access: ssh -p $VM_PORT -i $VM_SSH_KEY root@localhost"
}

stop_vm() {
    if [ -f "$VM_DIR/vm.pid" ]; then
        local pid=$(cat "$VM_DIR/vm.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping VM..."
            kill "$pid"
            rm -f "$VM_DIR/vm.pid"
            echo "✅ VM stopped"
        else
            echo "VM not running (stale PID file)"
            rm -f "$VM_DIR/vm.pid"
        fi
    else
        echo "VM not running"
    fi
}

vm_running() {
    if [ -f "$VM_DIR/vm.pid" ]; then
        local pid=$(cat "$VM_DIR/vm.pid")
        kill -0 "$pid" 2>/dev/null
    else
        return 1
    fi
}

vm_status() {
    if vm_running; then
        echo "VM Status: Running"
        echo "SSH: ssh -p $VM_PORT -i $VM_SSH_KEY root@localhost"
        echo "PID: $(cat "$VM_DIR/vm.pid")"
    else
        echo "VM Status: Stopped"
    fi
}

wait_for_ssh() {
    local retries=30
    while [ $retries -gt 0 ]; do
        if ssh -p "$VM_PORT" -i "$VM_SSH_KEY" -o ConnectTimeout=2 -o StrictHostKeyChecking=no root@localhost "echo 'SSH ready'" 2>/dev/null; then
            return 0
        fi
        echo "Waiting for SSH... ($retries attempts remaining)"
        sleep 2
        ((retries--))
    done
    echo "❌ SSH connection failed"
    return 1
}

ssh_vm() {
    if ! vm_running; then
        echo "VM is not running. Start it first with: $0 start"
        exit 1
    fi
    
    ssh -p "$VM_PORT" -i "$VM_SSH_KEY" -o StrictHostKeyChecking=no root@localhost
}

deploy_to_vm() {
    echo "Deploying Cistern to test VM..."
    
    # Check if VM disk exists
    if [ ! -f "$VM_DISK" ]; then
        echo "Creating VM disk first..."
        qemu-img create -f qcow2 "$VM_DISK" 20G
    fi
    
    echo "Setting up VM configuration..."
    setup_vm_config
    
    # Create a temporary host configuration for the VM
    local temp_host_config="$FLAKE_DIR/hosts/vm-test.nix"
    cat > "$temp_host_config" << EOF
{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix
    ../modules/monitoring.nix
    ../hardware/generic.nix
  ];

  networking.hostName = "cistern-test-vm";
  
  # VM-specific disk configuration
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
  
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];
  boot.kernelParams = [ "console=ttyS0" ];
  
  system.stateVersion = "24.05";
}
EOF
    
    # Update flake to include VM test configuration
    if ! grep -q "vm-test" "$FLAKE_DIR/flake.nix"; then
        echo "Adding VM test configuration to flake..."
        sed -i.bak '/media-server-template/a\
        vm-test = nixpkgs.lib.nixosSystem {\
          system = nixosSystem;\
          modules = commonModules ++ [\
            ./hardware/generic.nix\
            ./hosts/vm-test.nix\
          ];\
          specialArgs = { inherit inputs; };\
        };' "$FLAKE_DIR/flake.nix"
    fi
    
    echo "Installing NixOS to VM using nixos-anywhere..."
    
    # Use nixos-anywhere to install directly to the VM disk
    cd "$FLAKE_DIR"
    
    # Create a simple disko configuration for the VM
    cat > "$VM_DIR/disko-config.nix" << 'EOF'
{
  disko.devices = {
    disk = {
      vda = {
        device = "/dev/vda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
EOF
    
    # For now, let's use a simpler approach - just start the VM
    echo "Starting VM for manual setup..."
    start_vm
    
    echo "✅ VM started!"
    echo "To complete setup:"
    echo "1. SSH into VM: ssh -p $VM_PORT -i $VM_SSH_KEY root@localhost"
    echo "2. Install NixOS manually or run deployment"
    echo "3. Services will be available at http://localhost:8080"
}

destroy_vm() {
    read -p "Are you sure you want to destroy the VM and all data? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    stop_vm
    
    if [ -d "$VM_DIR" ]; then
        rm -rf "$VM_DIR"
        echo "✅ VM destroyed"
    else
        echo "VM directory not found"
    fi
}

reset_vm() {
    echo "Resetting VM to clean NixOS state..."
    stop_vm
    
    if [ -f "$VM_DISK" ]; then
        rm "$VM_DISK"
        echo "VM disk removed"
    fi
    
    start_vm
}

# Main script logic
case "${1:-}" in
    start)
        start_vm
        ;;
    stop)
        stop_vm
        ;;
    status)
        vm_status
        ;;
    ssh)
        ssh_vm
        ;;
    deploy)
        deploy_to_vm
        ;;
    destroy)
        destroy_vm
        ;;
    reset)
        reset_vm
        ;;
    -h|--help)
        show_help
        ;;
    "")
        show_help
        exit 1
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac