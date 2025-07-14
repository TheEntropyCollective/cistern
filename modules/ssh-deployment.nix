{ config, lib, pkgs, ... }:

# SSH Deployment Module - Secure SSH Configuration for Cistern
#
# SECURITY CONSIDERATIONS:
# 1. This module enforces secure SSH defaults:
#    - Root login is only allowed with SSH keys (never passwords)
#    - Password authentication is disabled by default
#    - Strong authentication limits to prevent brute force
#
# 2. Password authentication should ONLY be enabled temporarily:
#    - During initial server provisioning when SSH keys aren't yet deployed
#    - Must be disabled immediately after SSH keys are configured
#    - Never leave password authentication enabled in production
#
# 3. Best practices:
#    - Always use SSH keys for authentication
#    - Keep SSH keys secure and use passphrases
#    - Regularly rotate SSH keys
#    - Monitor auth logs for suspicious activity

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
      default = false;  # Changed default to false for security
      description = "Enable password authentication for deployment (NOT RECOMMENDED - use SSH keys instead)";
    };
  };

  config = mkIf cfg.enable {
    # SSH service configuration with security hardening
    services.openssh = {
      enable = true;
      settings = {
        # CRITICAL SECURITY: Only enable password auth if explicitly requested
        # This should only be used during initial deployment, then disabled
        PasswordAuthentication = mkIf cfg.enablePasswordAuth (mkForce true);
        
        # SECURITY: Never allow root login with password, only with SSH keys
        # "prohibit-password" allows root to login with keys but never with password
        PermitRootLogin = mkForce "prohibit-password";
        
        # Always enable public key authentication - this is the secure method
        PubkeyAuthentication = mkForce true;
        
        # Additional hardening when password auth is enabled
        # These settings help mitigate brute force attacks
        MaxAuthTries = mkDefault 3;
        MaxSessions = mkDefault 10;
        LoginGraceTime = mkDefault 60;  # 60 seconds to authenticate
      };
    };

    # Root user configuration
    users.users.root = {
      # Disable password login for root - SSH key only
      # This is more secure than having any password, even a random one
      hashedPassword = mkDefault "!";  # "!" means account is locked for password auth
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    # Deployment user configuration
    users.users.nixos = {
      isNormalUser = true;
      # Disable password login for nixos user - SSH key only
      # If password auth is needed, it should be explicitly set in host config
      hashedPassword = mkDefault "!";  # "!" means account is locked for password auth
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
    
    # Security warning when password authentication is enabled
    warnings = mkIf cfg.enablePasswordAuth [
      ''
        WARNING: SSH password authentication is enabled!
        This is a security risk and should only be used temporarily during initial deployment.
        Please disable password authentication and use SSH keys instead by setting:
        cistern.ssh.enablePasswordAuth = false;
      ''
    ];

    # Enable sudo without password for deployment user
    security.sudo.wheelNeedsPassword = false;
  };
}