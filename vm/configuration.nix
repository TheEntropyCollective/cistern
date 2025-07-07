{ config, pkgs, lib, ... }:

{
  imports = [ 
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];

  # Boot configuration for VM
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
  
  # Network configuration
  networking = {
    hostName = "cistern-test-vm";
    useDHCP = false;
    interfaces.enp0s3.useDHCP = true;
    
    # Open firewall for all Cistern services
    firewall = {
      enable = true;
      allowedTCPPorts = [ 
        22    # SSH
        80    # Nginx (main web interface)
        8096  # Jellyfin
        8989  # Sonarr  
        7878  # Radarr
        9696  # Prowlarr
        6767  # Bazarr
        9091  # Transmission
        3100  # Loki
        9100  # Prometheus node exporter
      ];
    };
  };
  
  # SSH configuration for testing
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "yes";
    };
  };
  
  # Create users for testing
  users.users = {
    root.openssh.authorizedKeys.keyFiles = [ ./vm_ssh_key.pub ];
    
    media = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      openssh.authorizedKeys.keyFiles = [ ./vm_ssh_key.pub ];
    };
  };
  
  # Disable password requirement for sudo (testing only)
  security.sudo.wheelNeedsPassword = false;
  
  # Install useful packages for testing and debugging
  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    htop
    jq
    yq-go
    tree
    vim
    tmux
  ];
  
  # Enable additional services for testing
  services = {
    # Enable automatic time sync
    timesyncd.enable = true;
    
    # Enable resolved for better DNS
    resolved.enable = true;
  };
  
  # VM-specific optimizations
  boot.kernelParams = [ "console=ttyS0" ];
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];
  
  # Set reasonable VM resource limits
  systemd.services."serial-getty@ttyS0".enable = true;
  
  system.stateVersion = "24.05";
}