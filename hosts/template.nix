{ config, pkgs, lib, ... }:

{
  # Template host configuration for new media servers
  # Copy this file and customize for each specific server
  
  networking = {
    hostName = "media-server-template";
    # hostId = ""; # Generate with: head -c4 /dev/urandom | od -A none -t x4
  };

  # Static IP configuration (optional)
  # networking.interfaces.eth0.ipv4.addresses = [{
  #   address = "192.168.1.100";
  #   prefixLength = 24;
  # }];
  # networking.defaultGateway = "192.168.1.1";
  # networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # Storage configuration
  # Add your specific mount points here
  # fileSystems."/mnt/media" = {
  #   device = "/dev/disk/by-uuid/your-uuid-here";
  #   fsType = "ext4";
  #   options = [ "defaults" "noatime" ];
  # };

  # Server-specific environment variables
  # environment.variables = {
  #   JELLYFIN_DATA_DIR = "/mnt/media/config/jellyfin";
  # };

  # Additional packages for this server
  environment.systemPackages = with pkgs; [
    # Add server-specific packages here
  ];

  # This is the template - actual servers should set their own state version
  system.stateVersion = "24.05";
}