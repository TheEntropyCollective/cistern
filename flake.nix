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
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixosSystem = "x86_64-linux";
      
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
          system = nixosSystem;
          modules = commonModules ++ [
            ./hardware/generic.nix
            ./hosts/template.nix
          ];
          specialArgs = { inherit inputs; };
        };
        
        # VM test configuration
        vm-test = nixpkgs.lib.nixosSystem {
          system = nixosSystem;
          modules = commonModules ++ [
            ./hardware/generic.nix
            ./hosts/vm-test.nix
          ];
          specialArgs = { inherit inputs; };
        };
        
        # Interactive VM test
        test-vm = nixpkgs.lib.nixosSystem {
          system = nixosSystem;
          modules = [
            ./test-vm.nix
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
      devShells = forAllSystems (system: 
        let 
          pkgs = nixpkgs.legacyPackages.${system};
          isLinux = system == "x86_64-linux" || system == "aarch64-linux";
        in
        pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            ssh-to-age
            age
            yq-go
            jq
            qemu
          ] ++ nixpkgs.lib.optionals isLinux [
            nixos-anywhere.packages.${system}.default or pkgs.hello
            deploy-rs.packages.${system}.default or pkgs.hello
          ];
          
          shellHook = ''
            echo "Cistern Media Server Fleet Management"
            echo "Available commands:"
            echo "  nixos-anywhere - Install NixOS on remote machines"
            echo "  deploy - Deploy configurations to existing fleet"
            echo "  qemu-system-x86_64 - QEMU for VM testing"
            echo ""
          '';
        });

      # VM for testing
      apps = forAllSystems (system: 
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          vm = {
            type = "app";
            program = "${self.nixosConfigurations.test-vm.config.system.build.vm}/bin/run-cistern-test-vm";
          };
        });

      # Utility scripts
      packages = forAllSystems (system: 
        let pkgs = nixpkgs.legacyPackages.${system}; in {
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
        });

      # Checks for CI/CD
      checks = forAllSystems (system: 
        nixpkgs.lib.optionalAttrs (system == "x86_64-linux" || system == "aarch64-linux") 
          (deploy-rs.lib.${system}.deployChecks self.deploy));
    };
}