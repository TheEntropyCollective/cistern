{ config, lib, pkgs, modulesPath, ... }:

{
  # Generic hardware configuration for most x86_64 systems
  # This can be overridden by specific hardware configurations
  
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration
  boot = {
    initrd = {
      availableKernelModules = [ 
        "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" 
        "sdhci_pci" "rtsx_pci_sdmmc" "r8169" "e1000e" "igb"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModulePackages = [ ];
  };

  # File systems - will be overridden by hardware-specific configs
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  # Swap configuration
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];

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