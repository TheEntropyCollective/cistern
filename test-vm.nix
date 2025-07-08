# NixOS VM test for Cistern
# Usage: nix run .#vm
{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/media-server.nix
    ./modules/monitoring.nix
  ];

  # VM-specific settings
  networking.hostName = "cistern-test";
  
  # Basic filesystem configuration for VM
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  
  # Enable VM testing
  virtualisation = {
    vmVariant = {
      virtualisation = {
        memorySize = 4096;
        cores = 2;
        diskSize = 20480; # 20GB
        forwardPorts = [
          { from = "host"; host.port = 8090; guest.port = 80; }      # Nginx/Dashboard
          { from = "host"; host.port = 8096; guest.port = 8096; }    # Jellyfin
          { from = "host"; host.port = 8081; guest.port = 8081; }    # Dashboard
          { from = "host"; host.port = 9091; guest.port = 9091; }    # Transmission
          { from = "host"; host.port = 8080; guest.port = 8080; }    # SABnzbd
          { from = "host"; host.port = 8989; guest.port = 8989; }    # Sonarr
          { from = "host"; host.port = 7878; guest.port = 7878; }    # Radarr
          { from = "host"; host.port = 9696; guest.port = 9696; }    # Prowlarr
          { from = "host"; host.port = 6767; guest.port = 6767; }    # Bazarr
        ];
      };
      
      # Faster boot for testing
      boot.loader.timeout = 1;
      
      # Enable SSH for debugging
      services.openssh.enable = true;
      
      # Create test user with password for easy access
      users.users.test = {
        isNormalUser = true;
        password = "test";
        extraGroups = [ "wheel" ];
      };
      
      # Allow SSH with password for testing
      services.openssh.settings.PasswordAuthentication = lib.mkForce true;
    };
  };

  system.stateVersion = "24.05";
}