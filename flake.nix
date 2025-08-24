{
  description = "Cistern Media Server Fleet";
  
  inputs = {
    # Use current stable NixOS 25.05
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };
  
  outputs = { self, nixpkgs }: {
    nixosConfigurations.cistern = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}