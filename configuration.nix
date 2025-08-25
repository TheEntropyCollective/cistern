{ config, pkgs, ... }:
{
  # Enable Cistern base system configuration
  cistern.base = {
    enable = true;
    hostname = "pishon"; # River name as per task 2
    timezone = "UTC";
    adminUser = "cistern";
  };

  # Boot configuration for UEFI systems
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Placeholder - will be managed by Disko in future task
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  # Nixarr media server configuration
  nixarr = {
    enable = true;
    # Standard directories as per Nixarr defaults
    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";
    
    # Enable Jellyfin media server
    jellyfin.enable = true;
    # sonarr.enable = true;
    # radarr.enable = true;
    # prowlarr.enable = true;
    # transmission.enable = true;
  };

  # Additional packages beyond base module
  # (Base packages like vim, git, htop are provided by modules/base.nix)

  # System state version - using current stable
  system.stateVersion = "25.05";
}

