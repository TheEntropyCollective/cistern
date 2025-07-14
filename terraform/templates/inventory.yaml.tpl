# Auto-generated Cistern Fleet Inventory from Terraform
# Generated on: ${timestamp()}

servers:
%{ for name, server in servers ~}
  ${name}:
    hostname: "${server.hostname}"
    hardware_type: "${server.hardware_type}"
    role: "${server.role}"
    vmid: ${server.vmid}
    memory: ${server.memory}
    cores: ${server.cores}
    deployed: "${timestamp()}"
    managed_by: "terraform"
    services:
      - jellyfin
      - sonarr
      - radarr
      - transmission
%{ if server.role == "primary" ~}
      - prowlarr
%{ endif ~}
%{ endfor ~}

# Network configuration
network:
  subnet: "${network.subnet}"
  gateway: "${network.gateway}"
  dns:
    - "1.1.1.1"
    - "8.8.8.8"

# Service distribution strategy
services:
%{ for name, server in servers ~}
%{ if server.role == "primary" ~}
  jellyfin:
    primary: "${name}"
    replicas: []
  
  sonarr:
    primary: "${name}"
    replicas: []
  
  radarr:
    primary: "${name}" 
    replicas: []
  
  prowlarr:
    primary: "${name}"
    replicas: []
  
  transmission:
    primary: "${name}"
    replicas: []
%{ endif ~}
%{ endfor ~}

# Storage strategy
storage:
  media_root: "/mnt/media"
  backup_locations: []
  replication: false

# Monitoring endpoints
monitoring:
  prometheus_port: 9090
  grafana_port: 3000
  loki_port: 3100
  alertmanager_port: 9093