{ config, pkgs, lib, ... }:

with lib;

{
  options = {
    cistern.base = {
      enable = mkEnableOption "Cistern base system configuration";
      
      hostname = mkOption {
        type = types.str;
        default = "cistern";
        description = "System hostname";
      };
      
      timezone = mkOption {
        type = types.str;
        default = "UTC";
        description = "System timezone";
      };
      
      adminUser = mkOption {
        type = types.str;
        default = "cistern";
        description = "Admin user name";
      };
    };
  };

  config = mkIf config.cistern.base.enable {
    # System Identity
    networking.hostName = config.cistern.base.hostname;
    time.timeZone = config.cistern.base.timezone;
    
    # Locale and Console
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us";
    };

    # Admin User Account
    users.users.${config.cistern.base.adminUser} = {
      isNormalUser = true;
      description = "Cistern Admin User";
      extraGroups = [ "wheel" "networkmanager" ];
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        # SSH keys will be managed by Agenix in future tasks
      ];
    };

    # Enable sudo for wheel group
    security.sudo.wheelNeedsPassword = false;

    # Network Configuration  
    networking = {
      networkmanager.enable = true;
      firewall = {
        enable = true;
        allowedTCPPorts = [ 
          22   # SSH access
          8096 # Jellyfin web interface
        ];
      };
    };

    # SSH Service
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # Essential System Packages
    environment.systemPackages = with pkgs; [
      vim
      git
      htop
      curl
      wget
    ];
  };
}