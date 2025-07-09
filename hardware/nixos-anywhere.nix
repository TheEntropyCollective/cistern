{ config, lib, pkgs, modulesPath, ... }:

{
  # Hardware configuration optimized for nixos-anywhere deployment
  # This uses automatic disk detection instead of fixed labels
  
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration
  boot = {
    initrd = {
      availableKernelModules = [ 
        "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" 
        "sdhci_pci" "rtsx_pci_sdmmc" "r8169" "e1000e" "igb"
        "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModulePackages = [ ];
    
    # Use GRUB for better compatibility
    loader = {
      grub = {
        enable = true;
        device = "/dev/sda"; # Will be auto-detected by nixos-anywhere
      };
    };
  };

  # File systems - nixos-anywhere will handle the partitioning
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  # Swap configuration - optional
  swapDevices = [ ];

  # Network hardware
  networking.useDHCP = lib.mkDefault true;
  
  # CPU and power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  
  # Enable hardware acceleration
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Hardware firmware
  hardware.enableRedistributableFirmware = true;
  
  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}