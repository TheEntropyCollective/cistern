# Cistern Secrets Configuration
# This file defines which secrets are available for each host

let
  # System administrators who can decrypt secrets
  admins = [
    # Add admin SSH public keys here to enable secret decryption
    # Example: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... admin@hostname"
  ];

  # Host-specific public keys (generated from SSH host keys)
  hosts = {
    # These will be populated automatically when hosts are deployed
    # Example: eden = "age1...";
  };

  # Helper to create secret definitions
  mkSecret = hosts: admins: {
    publicKeys = hosts ++ admins;
  };

in
{
  # Media service API keys
  "sonarr-api-key.age" = mkSecret (builtins.attrValues hosts) admins;
  "radarr-api-key.age" = mkSecret (builtins.attrValues hosts) admins;
  "prowlarr-api-key.age" = mkSecret (builtins.attrValues hosts) admins;
  "bazarr-api-key.age" = mkSecret (builtins.attrValues hosts) admins;
  "jellyfin-api-key.age" = mkSecret (builtins.attrValues hosts) admins;
  "sabnzbd-api-key.age" = mkSecret (builtins.attrValues hosts) admins;
  "transmission-rpc-password.age" = mkSecret (builtins.attrValues hosts) admins;

  # Authentication secrets
  "admin-password.age" = mkSecret (builtins.attrValues hosts) admins;
  "authentik-secret-key.age" = mkSecret (builtins.attrValues hosts) admins;
  "authentik-postgres-password.age" = mkSecret (builtins.attrValues hosts) admins;

  # Future secrets can be added here
}