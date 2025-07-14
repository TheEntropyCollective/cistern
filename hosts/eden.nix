{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/media-server.nix
    ../modules/monitoring.nix
    ../hardware/generic.nix
    ../modules/ssh-deployment.nix
  ];

  networking.hostName = "eden";
  
  # Configure static IP for Eden
  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.168.1.50";  # Adjust to your network
    prefixLength = 24;
  }];
  
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];

  # Eden is the primary server with all services
  cistern.media-server = {
    enable = true;
    primaryServer = true;
  };

  # Enable SSH deployment
  cistern.ssh = {
    enable = true;
    authorizedKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjZ2yKqEb+s4gz8It2vSNNnnZIJKs0GZsCdCJIUByk4Np5kqI7oi7NIPbzjOa5PLOhucGL/JyIi84Tr/0jr0to/1Ifc/iVXevjdhDsTvxxZkLCNl/GwGWflh59oFAyZ1whceKWYLOiU4su4q+OjdsaZDjHbtZVAppcoQf+u1hjvN1jmhrxaiGD8koUBjbsk2E4EnV2JjgqGoZYp3ujXf2q0xp/6yUrTyOJZlclee0Zd/Jf/mgiBOgWCXs7hQuAm8cO7fq00rQL+RINebqPIHGJUxXDnqsI6Qd+zn2x4vNy9D2BFZlmcR8S9K+2nHcYGSa4ROxQ4BLLgGZR3/Q019FeLsvXAoR2wwoFLLF/TEu1VMJlTN8ASSrMia5BdPdMMOh+uzZ3DyVvmKIN54NDXIdjyVQoF/FijwtRiTNBIj1MT87c7AmNNIGlBmBfduhbo9bnj/StFcYWODAR9KIkh1jr1RJhZ3fIdqY/7JTV5658uztBiZ+l2Tb4A2qCww9Kb2M= jconnuck@mac-bk"
    ];
  };

  system.stateVersion = "24.05";
}