{
  description = "Cistern Test VM Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          # VM-specific disk configuration
          fileSystems."/" = {
            device = "/dev/vda1";
            fsType = "ext4";
          };
          
          boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];
          boot.initrd.kernelModules = [ ];
          boot.kernelModules = [ ];
          boot.extraModulePackages = [ ];
        }
      ];
    };
    
    # Provide easy access to VM ISO
    packages.x86_64-linux.vm-iso = self.nixosConfigurations.vm.config.system.build.isoImage;
  };
}