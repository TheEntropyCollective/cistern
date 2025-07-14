# Terraform configuration for Cistern media server fleet

terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "~> 2.9"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.1"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_endpoint
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

# Generate inventory.yaml from Terraform state
resource "local_file" "inventory" {
  filename = "../inventory.yaml"
  content = templatefile("${path.module}/templates/inventory.yaml.tpl", {
    servers = merge(
      # Eden - physical server (manually provisioned)
      {
        "eden" = {
          hostname = "192.168.1.50"
          hardware_type = "generic"
          role = "primary"
          physical = true
        }
      },
      # River-named VMs from Terraform
      { for i, server in proxmox_vm_qemu.cistern_nodes : 
        var.river_names[i] => {
          hostname = cidrhost("${var.base_ip}/24", i + 1)
          hardware_type = "generic"
          role = "secondary"
          memory = var.memory
          cores = var.cores
          vmid = server.vmid
        }
      }
    )
    network = {
      subnet = "192.168.1.0/24"
      gateway = "192.168.1.1"
    }
  })
}

# Create NixOS host configurations for VMs
resource "local_file" "host_configs" {
  count = var.node_count
  filename = "../hosts/${var.river_names[count.index]}.nix"
  content = templatefile("${path.module}/templates/host.nix.tpl", {
    hostname = var.river_names[count.index]
    ip_address = cidrhost("${var.base_ip}/24", count.index + 1)
    ssh_public_key = var.ssh_public_key
    hardware_type = "generic"
    is_primary = count.index == 0
    admin_password_hash = var.admin_password_hash
  })
}

# Deploy Proxmox VMs
resource "proxmox_vm_qemu" "cistern_nodes" {
  count = var.node_count
  
  name        = var.river_names[count.index]
  vmid        = 200 + count.index
  target_node = "proxmox"
  
  # VM Resources
  memory  = var.memory
  cores   = var.cores
  sockets = 1
  
  # Storage
  disk {
    slot    = 0
    size    = "${var.storage}G"
    type    = "virtio"
    storage = "local-lvm"
  }
  
  # Network
  network {
    model  = "virtio"
    bridge = var.network_bridge
  }
  
  # Boot from NixOS ISO
  iso = var.nixos_iso_path
  
  # VM settings
  onboot = true
  agent  = 1
  
  # Static IP configuration
  ipconfig0 = "ip=${cidrhost("${var.base_ip}/24", count.index + 1)}/24,gw=192.168.1.1"
  
  # Wait for VM to be ready, then deploy Cistern
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for VM to boot..."
      sleep 120
      
      echo "Deploying Cistern to ${self.name}..."
      cd ${path.module}/..
      SSHPASS="nixos" nix run github:nix-community/nixos-anywhere -- \
        --flake .#${var.river_names[count.index]} \
        --env-password \
        nixos@${cidrhost("${var.base_ip}/24", count.index + 1)}
    EOT
    
    on_failure = continue
  }
  
  depends_on = [local_file.host_configs]
}

# Output server information
output "server_ips" {
  description = "IP addresses of deployed servers"
  value = { for i, server in proxmox_vm_qemu.cistern_nodes : 
    server.name => cidrhost("${var.base_ip}/24", i + 1)
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to servers"
  value = { for i, server in proxmox_vm_qemu.cistern_nodes : 
    server.name => "ssh root@${cidrhost("${var.base_ip}/24", i + 1)}"
  }
}