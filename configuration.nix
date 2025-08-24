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

  # Basic system packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
  ];

  # System state version - using current stable
  system.stateVersion = "25.05";
}

