{ config, pkgs, ... }:
{
  # Boot configuration for UEFI systems
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Placeholder - will be managed by Disko in task 1.2
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  networking.hostName = "pishon";

  # Nixarr media server configuration
  nixarr = {
    enable = false; # Will be enabled in later tasks
    # Standard directories as per Nixarr defaults
    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";
    
    # Services will be enabled in subsequent tasks:
    # jellyfin.enable = true;
    # sonarr.enable = true;
    # radarr.enable = true;
    # prowlarr.enable = true;
    # transmission.enable = true;
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
  ];

  # System state version - using current stable
  system.stateVersion = "25.05";
}

