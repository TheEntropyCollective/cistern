{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix  
    ../modules/monitoring.nix
    ../hardware/nixos-anywhere.nix
    ../disk-config.nix
  ];

  networking.hostName = "cistern-deploy-test";
  
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
    domain = "cistern-deploy-test.local";
    selfSigned = true;
  };

  # Override bootloader from base.nix to use GRUB instead of systemd-boot
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # SSH configuration for deployment
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkForce true;
      PermitRootLogin = lib.mkForce "yes";
    };
  };

  # Create nixos user with password for deployment
  users.users.nixos = {
    isNormalUser = true;
    password = "test123";
    extraGroups = [ "wheel" ];
  };

  # Enable sudo without password for nixos user (needed for deployment)
  security.sudo.wheelNeedsPassword = false;
  
  system.stateVersion = "24.05";
}