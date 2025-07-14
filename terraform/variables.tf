# Terraform variables for Cistern fleet deployment

variable "node_count" {
  description = "Number of Cistern media servers to deploy"
  type        = number
  default     = 3
}

variable "river_names" {
  description = "Biblical river names for servers"
  type        = list(string)
  default     = [
    "pishon",
    "gihon", 
    "tigris",
    "euphrates",
    "jordan",
    "jabbok",
    "arnon",
    "kishon",
    "nile",
    "pharpar"
  ]
}

variable "memory" {
  description = "Memory allocation per server (MB)"
  type        = number
  default     = 4096
}

variable "cores" {
  description = "CPU cores per server"
  type        = number
  default     = 4
}

variable "storage" {
  description = "Storage size per server (GB)"
  type        = number
  default     = 100
}

variable "network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "base_ip" {
  description = "Base IP address (will increment from this)"
  type        = string
  default     = "192.168.1.100"
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox API user"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "nixos_iso_path" {
  description = "Path to NixOS installer ISO on Proxmox"
  type        = string
  default     = "local:iso/nixos-minimal-24.05-x86_64-linux.iso"
}

variable "admin_password_hash" {
  description = "Bcrypt hash of admin password for web auth (optional - auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}