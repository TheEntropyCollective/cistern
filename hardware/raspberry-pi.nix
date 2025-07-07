{ config, lib, pkgs, modulesPath, ... }:

{
  # Hardware configuration for Raspberry Pi 4/5
  
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration for ARM
  boot = {
    initrd = {
      availableKernelModules = [ 
        "usbhid" "usb_storage" "vc4" "pcie_brcmstb" "reset-raspberrypi"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ ];
    extraModulePackages = [ ];
    
    # Raspberry Pi specific boot
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  # File systems for SD card/USB boot
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "nofail" "noauto" ];
  };

  # No swap on Pi (preserve SD card)
  swapDevices = [ ];

  # Network hardware
  networking.useDHCP = lib.mkDefault true;
  
  # ARM-specific settings
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  
  # GPU acceleration for Pi
  hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;
  hardware.raspberry-pi."4".fkms-3d.enable = true;
  
  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  
  # Pi-specific optimizations
  boot.kernel.sysctl = {
    # Reduce memory pressure on Pi
    "vm.dirty_ratio" = 1;
    "vm.dirty_background_ratio" = 1;
    "vm.dirty_writeback_centisecs" = 100;
    "vm.dirty_expire_centisecs" = 200;
  };
}