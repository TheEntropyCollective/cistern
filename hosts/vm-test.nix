{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix  
    ../modules/monitoring.nix
    ../hardware/generic.nix
  ];

  networking.hostName = "cistern-test-vm";
  
  # VM-specific disk configuration (override generic hardware config)
  # Only root filesystem needed for GRUB BIOS boot
  fileSystems = lib.mkForce {
    "/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };
  };
  
  # No swap for VM
  swapDevices = lib.mkForce [ ];
  
  boot = {
    loader = {
      # Disable systemd-boot for VM (use GRUB instead)
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
      grub = {
        enable = true;
        device = "/dev/vda";
      };
    };
    kernelParams = [ "console=ttyS0,115200" ];
    initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];
  };
  
  # Enable all Cistern services for testing
  services = {
    jellyfin.enable = true;
    nginx.enable = true;
    openssh.enable = true;
  };
  
  # Open firewall for all media services
  networking.firewall.allowedTCPPorts = [ 22 80 8096 8989 7878 9696 6767 9091 3100 9100 ];
  
  # VM-specific user setup - SSH key will be set up during deployment
  
  system.stateVersion = "24.05";
}
