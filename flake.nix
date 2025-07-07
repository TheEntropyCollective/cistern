{
  description = "Cistern Media Server Fleet Management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, deploy-rs, nixos-anywhere, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      # Common modules shared across all servers
      commonModules = [
        ./modules/base.nix
        ./modules/media-server.nix
        ./modules/monitoring.nix
      ];
    in
    {
      # NixOS configurations for different server types
      nixosConfigurations = {
        # Template configuration for new media servers
        media-server-template = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            ./hardware/generic.nix
            ./hosts/template.nix
          ];
          specialArgs = { inherit inputs; };
        };
      };

      # Deploy-rs configuration for fleet management
      deploy.nodes = {
        # Example server - add your actual servers here
        # media-server-01 = {
        #   hostname = "192.168.1.100";
        #   profiles.system = {
        #     user = "root";
        #     path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.media-server-01;
        #   };
        # };
      };

      # Development shell with deployment tools
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixos-anywhere.packages.${system}.default
          deploy-rs.packages.${system}.default
          git
          ssh-to-age
          age
        ];
        
        shellHook = ''
          echo "Cistern Media Server Fleet Management"
          echo "Available commands:"
          echo "  nixos-anywhere - Install NixOS on remote machines"
          echo "  deploy - Deploy configurations to existing fleet"
          echo ""
        '';
      };

      # Utility scripts
      packages.${system} = {
        provision-server = pkgs.writeShellScriptBin "provision-server" ''
          #!/usr/bin/env bash
          set -euo pipefail
          
          if [ $# -ne 2 ]; then
            echo "Usage: provision-server <hostname/ip> <hardware-config>"
            echo "Example: provision-server 192.168.1.100 generic"
            exit 1
          fi
          
          HOST=$1
          HARDWARE=$2
          
          echo "Provisioning new media server at $HOST with $HARDWARE hardware config..."
          
          nixos-anywhere --flake .#media-server-template \
            --build-on-remote \
            root@$HOST
        '';
        
        deploy-fleet = pkgs.writeShellScriptBin "deploy-fleet" ''
          #!/usr/bin/env bash
          set -euo pipefail
          
          echo "Deploying to entire media server fleet..."
          deploy .#
        '';
      };

      # Checks for CI/CD
      checks.${system} = deploy-rs.lib.${system}.deployChecks self.deploy;
    };
}