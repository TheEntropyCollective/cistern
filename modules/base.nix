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
      # Security hardening
      PermitRootLogin = "prohibit-password";  # Allow root login only with SSH keys, never with password
      PasswordAuthentication = false;          # Disable password authentication entirely
      PubkeyAuthentication = true;            # Enable public key authentication
      ChallengeResponseAuthentication = false; # Disable challenge-response authentication
      KbdInteractiveAuthentication = false;    # Disable keyboard-interactive authentication
      UsePAM = false;                         # Disable PAM authentication to ensure no password fallback
      X11Forwarding = false;                  # Disable X11 forwarding for security
      PermitEmptyPasswords = false;           # Never allow empty passwords
      MaxAuthTries = 3;                       # Limit authentication attempts
      ClientAliveInterval = 300;              # Send keep-alive every 5 minutes
      ClientAliveCountMax = 2;                # Disconnect after 2 failed keep-alives (10 min inactive)
      # Additional hardening
      Protocol = 2;                           # Use only SSH protocol 2
      StrictModes = true;                     # Check file permissions
      IgnoreRhosts = true;                    # Ignore .rhosts files
      HostbasedAuthentication = false;        # Disable host-based authentication
      PermitUserEnvironment = false;          # Don't allow users to set environment options
    };
    # Additional security: limit SSH access by user
    extraConfig = ''
      # Only allow specific users to SSH in
      AllowUsers root media nixos
      # Use strong ciphers and algorithms
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
      MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
      KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
    '';
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
  
  # Fail2ban configuration for brute force protection
  services.fail2ban = {
    enable = true;
    # Maximum number of retries before banning
    maxretry = 5;
    # Ban time in seconds (1 hour)
    bantime = "1h";
    # Time window for maxretry (10 minutes)
    findtime = "10m";
    # Ignore local network IPs from banning
    ignoreIP = [
      "127.0.0.1/8"
      "192.168.0.0/16"
      "10.0.0.0/8"
      "172.16.0.0/12"
    ];
    
    # SSH jail configuration
    jails = {
      ssh = {
        settings = {
          enabled = true;
          filter = "sshd";
          port = "22";
          logpath = "/var/log/auth.log";
          backend = "systemd";
          maxretry = 3;  # More strict for SSH
          bantime = "2h";  # Longer ban time for SSH attempts
          findtime = "20m";
        };
      };
    };
  };
  
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