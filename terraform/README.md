# Terraform Integration for Cistern Fleet

This directory contains Terraform configurations for automating Cistern media server fleet deployment.

## Features

- **Infrastructure as Code**: Define your entire fleet in Terraform
- **Auto-scaling**: Deploy 1-20 servers with a single command
- **State Management**: Track and modify infrastructure over time
- **Integration**: Automatically generates NixOS configs and inventory.yaml
- **Multi-provider**: Support for Proxmox, AWS, Azure, etc.

## Quick Start

### 1. Setup Terraform
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 2. Initialize and Deploy
```bash
terraform init
terraform plan
terraform apply
```

### 3. Scale Your Fleet
```bash
# Scale to 5 servers
terraform apply -var="node_count=5"

# Scale down to 2 servers  
terraform apply -var="node_count=2"
```

## What This Does

1. **Creates VMs** on your infrastructure provider (Proxmox/AWS/etc.)
2. **Generates NixOS configs** for each server automatically
3. **Updates inventory.yaml** with all server details
4. **Deploys Cistern** using nixos-anywhere to each VM
5. **Configures networking** with static IPs and proper DNS

## Supported Providers

### Proxmox (Default)
```hcl
# Deploys VMs on local Proxmox cluster
resource "proxmox_vm_qemu" "cistern_nodes" { ... }
```

### AWS EC2
```hcl
# Deploy to AWS cloud
resource "aws_instance" "cistern_nodes" { ... }
```

### Libvirt/KVM
```hcl  
# Local KVM/QEMU deployment
resource "libvirt_domain" "cistern_nodes" { ... }
```

## Benefits Over Manual Deployment

| Manual Process | Terraform Process |
|---|---|
| Copy template.nix → Edit hostname → Deploy | `terraform apply` |
| Track servers manually | Automatic state management |
| Scale one by one | Scale entire fleet at once |
| Manual IP assignment | Automatic IP management |
| Update inventory.yaml manually | Auto-generated from infrastructure |

## Fleet Management Commands

```bash
# Deploy 3-server fleet
terraform apply -var="node_count=3"

# Add more storage to all servers
terraform apply -var="storage=200"

# Scale up to 10 servers
terraform apply -var="node_count=10"

# Destroy specific server
terraform destroy -target=proxmox_vm_qemu.cistern_nodes[2]

# Show all server IPs
terraform output server_ips

# Get SSH commands for all servers
terraform output ssh_commands
```

## Directory Structure

```
terraform/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── terraform.tfvars.example   # Configuration template
├── templates/
│   ├── inventory.yaml.tpl     # Auto-generates inventory.yaml
│   └── host.nix.tpl          # Auto-generates host configs
└── README.md                 # This file
```

## Integration with Existing Workflow

Terraform **enhances** the existing Cistern workflow:

1. **Infrastructure**: Terraform creates and manages VMs
2. **Configuration**: NixOS manages system configuration  
3. **Fleet Management**: inventory.yaml tracks everything
4. **Updates**: deploy-rs handles ongoing configuration changes

You keep all the benefits of NixOS declarative configuration while gaining automated infrastructure management.