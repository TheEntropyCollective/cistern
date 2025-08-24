{
  description = "Cistern Media Server Fleet";
  
  inputs = {
    # Use current stable NixOS 25.05
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Nixarr media server stack
    nixarr.url = "github:rasmus-kirk/nixarr";
  };
  
  outputs = { self, nixpkgs, nixarr }: {
    nixosConfigurations.cistern = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ 
        ./configuration.nix
        nixarr.nixosModules.default
      ];
    };
  };
}