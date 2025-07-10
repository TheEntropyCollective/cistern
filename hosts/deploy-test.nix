{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix  
    ../modules/monitoring.nix
    ../hardware/nixos-anywhere.nix
    ../disk-configs/vda.nix
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
    initialPassword = "test123";  # Using initialPassword instead of password
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjZ2yKqEb+s4gz8It2vSNNnnZIJKs0GZsCdCJIUByk4Np5kqI7oi7NIPbzjOa5PLOhucGL/JyIi84Tr/0jr0to/1Ifc/iVXevjdhDsTvxxZkLCNl/GwGWflh59oFAyZ1whceKWYLOiU4su4q+OjdsaZDjHbtZVAppcoQf+u1hjvN1jmhrxaiGD8koUBjbsk2E4EnV2JjgqGoZYp3ujXf2q0xp/6yUrTyOJZlclee0Zd/Jf/mgiBOgWCXs7hQuAm8cO7fq00rQL+RINebqPIHGJUxXDnqsI6Qd+zn2x4vNy9D2BFZlmcR8S9K+2nHcYGSa4ROxQ4BLLgGZR3/Q019FeLsvXAoR2wwoFLLF/TEu1VMJlTN8ASSrMia5BdPdMMOh+uzZ3DyVvmKIN54NDXIdjyVQoF/FijwtRiTNBIj1MT87c7AmNNIGlBmBfduhbo9bnj/StFcYWODAR9KIkh1jr1RJhZ3fIdqY/7JTV5658uztBiZ+l2Tb4A2qCww9Kb2M= jconnuck@mac-bk"
    ];
  };
  
  # Also add SSH key to root for easier access
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjZ2yKqEb+s4gz8It2vSNNnnZIJKs0GZsCdCJIUByk4Np5kqI7oi7NIPbzjOa5PLOhucGL/JyIi84Tr/0jr0to/1Ifc/iVXevjdhDsTvxxZkLCNl/GwGWflh59oFAyZ1whceKWYLOiU4su4q+OjdsaZDjHbtZVAppcoQf+u1hjvN1jmhrxaiGD8koUBjbsk2E4EnV2JjgqGoZYp3ujXf2q0xp/6yUrTyOJZlclee0Zd/Jf/mgiBOgWCXs7hQuAm8cO7fq00rQL+RINebqPIHGJUxXDnqsI6Qd+zn2x4vNy9D2BFZlmcR8S9K+2nHcYGSa4ROxQ4BLLgGZR3/Q019FeLsvXAoR2wwoFLLF/TEu1VMJlTN8ASSrMia5BdPdMMOh+uzZ3DyVvmKIN54NDXIdjyVQoF/FijwtRiTNBIj1MT87c7AmNNIGlBmBfduhbo9bnj/StFcYWODAR9KIkh1jr1RJhZ3fIdqY/7JTV5658uztBiZ+l2Tb4A2qCww9Kb2M= jconnuck@mac-bk"
  ];

  # Enable sudo without password for nixos user (needed for deployment)
  security.sudo.wheelNeedsPassword = false;
  
  system.stateVersion = "24.05";
}