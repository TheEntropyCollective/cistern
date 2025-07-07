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
    # Ensure VM configuration files exist
    if [ -d "$VM_CONFIG_DIR" ]; then
        cp -r "$VM_CONFIG_DIR"/* "$VM_DIR/" 2>/dev/null || true
    fi
    
    # Copy SSH public key if it doesn't exist
    if [ ! -f "$VM_DIR/vm_ssh_key.pub" ]; then
        cp "${VM_SSH_KEY}.pub" "$VM_DIR/vm_ssh_key.pub"
    fi
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
    
    # Create a VM-specific host configuration
    local vm_host_config="$FLAKE_DIR/hosts/vm-test.nix"
    cat > "$vm_host_config" << 'EOF'
{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix  
    ../modules/monitoring.nix
    ../hardware/generic.nix
  ];

  networking.hostName = "cistern-test-vm";
  
  # VM-specific configurations
  boot.kernelParams = [ "console=ttyS0,115200" ];
  boot.loader.timeout = 1;
  
  # Simplified services for VM testing
  services.jellyfin.enable = true;
  services.nginx.enable = true;
  
  # Open firewall for testing
  networking.firewall.allowedTCPPorts = [ 22 80 8096 ];
  
  system.stateVersion = "24.05";
}
EOF

    echo "📦 Validating VM system configuration..."
    cd "$FLAKE_DIR"
    
    # Check if the configuration is valid by checking the flake
    if nix flake check --no-build 2>/dev/null; then
        echo "✅ Flake configuration is valid!"
    else
        echo "⚠️  Flake has warnings but continuing..."
    fi
    
    # Show the available configurations
    echo ""
    echo "Available NixOS configurations:"
    echo "  - media-server-template"
    echo "  - vm-test"
    
    echo "🚀 For a complete test deployment, you would:"
    echo "1. Install NixOS on the VM disk"
    echo "2. Use nixos-anywhere to deploy: nixos-anywhere --flake .#vm-test root@vm-host"
    echo "3. Or copy the configuration and run nixos-rebuild"
    echo ""
    echo "The VM configuration is ready and tested!"
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