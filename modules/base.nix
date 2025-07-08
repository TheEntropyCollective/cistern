{ config, pkgs, lib, ... }:

{
  # System-wide configuration for all Cistern media servers
  
  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.cleanOnBoot = true;
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
      allowedUDPPorts = [ ];
    };
  };

  # Time and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Users
  users.users.root = {
    openssh.authorizedKeys.keys = [
      # Add your SSH public keys here
    ];
  };

  users.users.media = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "media" ];
    openssh.authorizedKeys.keys = [
      # Add your SSH public keys here
    ];
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    htop
    btop
    iotop
    ncdu
    tree
    rsync
    tmux
    vim
    age
    ssh-to-age
  ];

  # Security
  security.sudo.wheelNeedsPassword = false;
  
  # Automatic garbage collection
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Allow unfree packages (needed for SABnzbd's unrar dependency)
  nixpkgs.config.allowUnfree = true;

  # System version
  system.stateVersion = "24.05";
}