{
  description = "Cistern Media Server Fleet";
  
  inputs = {
    # Use current stable NixOS 25.05
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Nixarr media server stack
    nixarr.url = "github:rasmus-kirk/nixarr";
    # NixOS generators for creating VM images
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { self, nixpkgs, nixarr, nixos-generators }: 
  let
    # Target architecture for Cistern deployments
    system = "x86_64-linux";
    
    # Core Cistern media server modules
    modules = [
      ./configuration.nix
      ./modules/base.nix
      nixarr.nixosModules.default
    ];
  in
  {
    nixosConfigurations.cistern = nixpkgs.lib.nixosSystem {
      inherit system modules;
    };

    # VM images for testing
    packages.x86_64-linux.cistern-iso = nixos-generators.nixosGenerate {
      inherit system modules;
      format = "iso";
    };

    # Also provide packages for macOS (for cross-building)
    packages.aarch64-darwin.cistern-iso = nixos-generators.nixosGenerate {
      inherit system modules;
      format = "iso";
    };
  };
}