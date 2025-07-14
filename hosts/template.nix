{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/ssh-deployment.nix
  ];

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
    method = "basic";  # "basic" for htpasswd auth, "authentik" for SSO
    sessionTimeout = 7200;  # 2 hours
    allowedIPs = [
      "127.0.0.1"
      "192.168.0.0/16"
      "10.0.0.0/8"
      "172.16.0.0/12"
    ];
    
    # Basic authentication users (when method = "basic")
    users = {
      # Default admin user will be created automatically
      # Add additional users here:
      # "admin" = "$2y$10$...";  # Use htpasswd to generate
    };
    
    # Authentik configuration (when method = "authentik")
    authentik = {
      domain = "auth.${config.networking.hostName}.local";
      provider = "cistern-proxy-provider";
      outpost = "cistern-nginx-outpost";
    };
  };

  # Enable Authentik SSO identity provider (optional)
  cistern.authentik = {
    enable = false;  # Set to true to enable Authentik
    domain = "auth.${config.networking.hostName}.local";
    
    # Database configuration
    database = {
      host = "localhost";
      port = 5432;
      name = "authentik";
      user = "authentik";
      # passwordFile will be auto-generated if not specified
    };
    
    # Redis configuration
    redis = {
      host = "localhost";
      port = 6379;
    };
    
    # Admin user
    admin = {
      email = "admin@${config.networking.hostName}.local";
      username = "admin";
      # passwordFile will be auto-generated if not specified
    };
    
    # SMTP configuration (optional)
    smtp = {
      enable = false;
      host = "";  # e.g., "smtp.gmail.com"
      port = 587;
      user = "";  # e.g., "your-email@gmail.com"
      from = "authentik@${config.networking.hostName}.local";
      useTLS = true;
      # passwordFile = "/var/lib/cistern/authentik/smtp-password";
    };
    
    # Outpost configuration
    outpost = {
      name = "cistern-nginx-outpost";
      # token will be auto-generated if not specified
    };
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

  # Authentication Mode Configuration:
  #
  # BASIC AUTHENTICATION (default):
  # - Simple htpasswd-based authentication
  # - Users defined in cistern.auth.users
  # - Suitable for personal use or small teams
  # - No external dependencies
  #
  # AUTHENTIK SSO:
  # - Modern identity provider with SSO, 2FA, OIDC
  # - Requires PostgreSQL and Redis
  # - Supports multiple authentication methods
  # - Centralized user management and audit logs
  # - To enable: Set cistern.authentik.enable = true and cistern.auth.method = "authentik"
  #
  # Example Authentik setup:
  # 1. Set cistern.authentik.enable = true
  # 2. Set cistern.auth.method = "authentik"
  # 3. Configure SMTP for email notifications (optional)
  # 4. Deploy and access https://auth.hostname.local to complete setup

  # Enable NoiseFS distributed storage
  cistern.noisefs = {
    enable = true;
    mountPoint = "/mnt/media/noisefs";
    
    # Configure IPFS network
    ipfs = {
      networkMode = "private";  # "private" for fleet-only, "public" for global IPFS
      apiPort = 5001;
      gatewayPort = 8081;
      swarmPort = 4001;
      # swarmKey = ""; # Only used in private mode, set same key across fleet
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
  
  # NoiseFS Network Mode Explanation:
  # 
  # PRIVATE MODE (default):
  # - Creates isolated IPFS network using only fleet servers
  # - Requires swarm key shared across all servers
  # - Data never leaves your infrastructure
  # - Maximum privacy and security
  # - Use: cistern-noisefs-swarm for key management
  #
  # PUBLIC MODE:
  # - Connects to global IPFS network + fleet servers
  # - No swarm key needed
  # - Access to global IPFS content and redundancy
  # - NoiseFS anonymization still protects file content
  # - Better performance from larger network

  # SSH deployment configuration
  cistern.ssh = {
    enable = true;
    enablePasswordAuth = true;
    authorizedKeys = [
      # Add your SSH public keys here for automatic deployment access
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjZ2yKqEb+s4gz8It2vSNNnnZI
  JKs0GZsCdCJIUByk4Np5kqI7oi7NIPbzjOa5PLOhucGL/JyIi84Tr/0jr0to/1Ifc
  /iVXevjdhDsTvxxZkLCNl/GwGWflh59oFAyZ1whceKWYLOiU4su4q+OjdsaZDjHbt
  ZVAppcoQf+u1hjvN1jmhrxaiGD8koUBjbsk2E4EnV2JjgqGoZYp3ujXf2q0xp/6yU
  rTyOJZlclee0Zd/Jf/mgiBOgWCXs7hQuAm8cO7fq00rQL+RINebqPIHGJUxXDnqsI
  6Qd+zn2x4vNy9D2BFZlmcR8S9K+2nHcYGSa4ROxQ4BLLgGZR3/Q019FeLsvXAoR2w
  woFLLF/TEu1VMJlTN8ASSrMia5BdPdMMOh+uzZ3DyVvmKIN54NDXIdjyVQoF/Fijw
  tRiTNBIj1MT87c7AmNNIGlBmBfduhbo9bnj/StFcYWODAR9KIkh1jr1RJhZ3fIdqY
  /7JTV5658uztBiZ+l2Tb4A2qCww9Kb2M= jconnuck@mac-bk"
    ];
  };

  # Additional packages for this server
  environment.systemPackages = with pkgs; [
    # Add server-specific packages here
  ];

  # This is the template - actual servers should set their own state version
  system.stateVersion = "24.05";
}