{ config, pkgs, lib, ... }:

{
  # Template host configuration for new media servers
  # Copy this file and customize for each specific server
  
  networking = {
    hostName = "media-server-template";
    # hostId = ""; # Generate with: head -c4 /dev/urandom | od -A none -t x4
  };

  # Static IP configuration (optional)
  # networking.interfaces.eth0.ipv4.addresses = [{
  #   address = "192.168.1.100";
  #   prefixLength = 24;
  # }];
  # networking.defaultGateway = "192.168.1.1";
  # networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # Storage configuration
  # Add your specific mount points here
  # fileSystems."/mnt/media" = {
  #   device = "/dev/disk/by-uuid/your-uuid-here";
  #   fsType = "ext4";
  #   options = [ "defaults" "noatime" ];
  # };

  # Server-specific environment variables
  # environment.variables = {
  #   JELLYFIN_DATA_DIR = "/mnt/media/config/jellyfin";
  # };

  # Privacy and authentication configuration
  cistern.privacy = {
    enable = true;
    vpn = {
      enable = false;  # Enable and configure VPN if needed
      provider = "wireguard";
      configFile = "/etc/wireguard/wg0.conf";
      killSwitch = true;
    };
    dns = {
      provider = "quad9";
      dnsOverHttps = true;
    };
    authentication = {
      enable = true;
      # Default admin user will be created automatically
      # Add additional users here:
      # users = {
      #   "admin" = "$2y$10$...";  # Use htpasswd to generate
      # };
    };
  };

  # Enable authentication for web services
  cistern.auth = {
    enable = true;
    sessionTimeout = 7200;  # 2 hours
    allowedIPs = [
      "127.0.0.1"
      "192.168.0.0/16"
      "10.0.0.0/8"
      "172.16.0.0/12"
    ];
  };

  # Enable SSL certificates
  cistern.ssl = {
    enable = true;
    domain = "${config.networking.hostName}.local";
    selfSigned = true;  # Use self-signed certificates
    certificateValidityDays = 365;
    # For Let's Encrypt certificates, enable ACME:
    # acme = {
    #   enable = true;
    #   email = "admin@example.com";
    # };
  };

  # Enable NoiseFS with private IPFS network
  cistern.noisefs = {
    enable = true;
    mountPoint = "/mnt/media/noisefs";
    
    # Configure private IPFS network
    ipfs = {
      apiPort = 5001;
      gatewayPort = 8081;
      swarmPort = 4001;
      # swarmKey = ""; # Set same key across all fleet members
    };
    
    # NoiseFS configuration
    noisefs = {
      webPort = 8082;  # NoiseFS web UI
      blockSize = 131072;  # 128KB blocks
    };
    
    # Fleet configuration - add your server IPs here
    fleet = {
      servers = [
        # "192.168.1.100"  # media-server-01
        # "192.168.1.101"  # media-server-02
        # "192.168.1.102"  # media-server-03
      ];
    };
  };

  # Additional packages for this server
  environment.systemPackages = with pkgs; [
    # Add server-specific packages here
  ];

  # This is the template - actual servers should set their own state version
  system.stateVersion = "24.05";
}