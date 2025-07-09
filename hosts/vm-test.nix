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
  
  # Additional firewall ports for VM testing
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Enable enhanced basic authentication for testing
  cistern.auth = {
    enable = true;
    method = "basic";  # Use enhanced basic auth system
    users = {
      # Test user (password: "test123")
      "test" = "$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi";
    };
  };

  # Enable SSL for secure testing
  cistern.ssl = {
    enable = true;
    domain = "cistern-test-vm.local";
    selfSigned = true;
  };
  
  system.stateVersion = "24.05";
}
