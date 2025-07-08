{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix  
    ../modules/monitoring.nix
    ../hardware/generic.nix
  ];

  networking.hostName = "cistern-test-vm";
  
  # VM-specific configurations
  boot.kernelParams = [ "console=ttyS0,115200" ];
  boot.loader.timeout = 1;
  
  # Simplified services for VM testing
  services.jellyfin.enable = true;
  services.nginx.enable = true;
  
  # Open firewall for testing
  networking.firewall.allowedTCPPorts = [ 22 80 8096 ];
  
  system.stateVersion = "24.05";
}
