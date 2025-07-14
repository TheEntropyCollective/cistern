# Terraform configuration for Cistern fleet
# Adjust these values for your environment

# Fleet size - start with 2 VMs (Pishon and Gihon)
node_count = 2

# VM resources
memory = 4096  # MB
cores  = 4
storage = 100  # GB

# Network configuration
network_bridge = "vmbr0"
base_ip = "192.168.1.100"  # VMs will be .101, .102, etc

# SSH access
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjZ2yKqEb+s4gz8It2vSNNnnZIJKs0GZsCdCJIUByk4Np5kqI7oi7NIPbzjOa5PLOhucGL/JyIi84Tr/0jr0to/1Ifc/iVXevjdhDsTvxxZkLCNl/GwGWflh59oFAyZ1whceKWYLOiU4su4q+OjdsaZDjHbtZVAppcoQf+u1hjvN1jmhrxaiGD8koUBjbsk2E4EnV2JjgqGoZYp3ujXf2q0xp/6yUrTyOJZlclee0Zd/Jf/mgiBOgWCXs7hQuAm8cO7fq00rQL+RINebqPIHGJUxXDnqsI6Qd+zn2x4vNy9D2BFZlmcR8S9K+2nHcYGSa4ROxQ4BLLgGZR3/Q019FeLsvXAoR2wwoFLLF/TEu1VMJlTN8ASSrMia5BdPdMMOh+uzZ3DyVvmKIN54NDXIdjyVQoF/FijwtRiTNBIj1MT87c7AmNNIGlBmBfduhbo9bnj/StFcYWODAR9KIkh1jr1RJhZ3fIdqY/7JTV5658uztBiZ+l2Tb4A2qCww9Kb2M= jconnuck@mac-bk"

# Proxmox connection - UPDATE THESE VALUES
proxmox_endpoint = "https://proxmox.local:8006/api2/json"  # Change to your Proxmox server
proxmox_user = "terraform@pve"  # Your Proxmox user
proxmox_password = "your-password-here"  # Your Proxmox password

# NixOS ISO (you'll need to upload this to Proxmox first)
nixos_iso_path = "local:iso/nixos-minimal-24.05-x86_64-linux.iso"