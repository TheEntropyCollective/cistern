{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.cistern.ssh;
in
{
  options.cistern.ssh = {
    enable = mkEnableOption "Enable SSH deployment configuration";
    
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of SSH public keys to authorize";
    };
    
    enablePasswordAuth = mkOption {
      type = types.bool;
      default = true;
      description = "Enable password authentication for deployment";
    };
  };

  config = mkIf cfg.enable {
    # SSH service configuration
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = mkIf cfg.enablePasswordAuth (mkForce true);
        PermitRootLogin = mkForce "yes";
        PubkeyAuthentication = mkForce true;
      };
    };

    # Root user configuration
    users.users.root = {
      hashedPassword = mkDefault "";
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    # Deployment user configuration
    users.users.nixos = {
      isNormalUser = true;
      hashedPassword = mkDefault "";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    # Ensure SSH directories are created properly at boot
    system.activationScripts.sshSetup = ''
      # Ensure root SSH directory exists with correct permissions
      mkdir -p /root/.ssh
      chmod 700 /root/.ssh
      
      # Ensure nixos user SSH directory exists with correct permissions  
      mkdir -p /home/nixos/.ssh
      chmod 700 /home/nixos/.ssh
      chown nixos:users /home/nixos/.ssh
    '';

    # Enable sudo without password for deployment user
    security.sudo.wheelNeedsPassword = false;
  };
}