{ config, pkgs, lib, ... }:

with lib;

{
  # Authentication module for Cistern media services
  # Provides unified login protection for all web interfaces

  options.cistern.auth = {
    enable = mkEnableOption "Enable authentication for web services";
    
    method = mkOption {
      type = types.enum [ "basic" "authentik" ];
      default = "basic";
      description = "Authentication method: basic (htpasswd) or authentik (SSO)";
    };
    
    users = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {
        "admin" = "$2y$10$..."; # bcrypt hash
        "user" = "$2y$10$...";
      };
      description = "Username to bcrypt password hash mapping (basic auth only)";
    };
    
    sessionTimeout = mkOption {
      type = types.int;
      default = 7200; # 2 hours
      description = "Session timeout in seconds";
    };
    
    allowedIPs = mkOption {
      type = types.listOf types.str;
      default = [ "127.0.0.1" "192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" ];
      description = "IP addresses/ranges allowed to access services";
    };
    
    authentik = {
      domain = mkOption {
        type = types.str;
        default = config.cistern.authentik.domain or "auth.${config.networking.hostName}.local";
        description = "Authentik domain for auth_request";
      };
      
      provider = mkOption {
        type = types.str;
        default = "cistern-proxy-provider";
        description = "Authentik proxy provider name";
      };
      
      outpost = mkOption {
        type = types.str;
        default = config.cistern.authentik.outpost.name or "cistern-nginx-outpost";
        description = "Authentik outpost name";
      };
    };
  };

  config = mkIf config.cistern.auth.enable {
    
    # Basic auth configuration (htpasswd)
    systemd.tmpfiles.rules = mkIf (config.cistern.auth.method == "basic") [
      "d /var/lib/cistern/auth 0755 nginx nginx -"
    ];

    # Create htpasswd file from user configuration (basic auth only)
    systemd.services.cistern-auth-setup = mkIf (config.cistern.auth.method == "basic") {
      description = "Setup Cistern authentication";
      wantedBy = [ "multi-user.target" ];
      before = [ "nginx.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
      };
      
      script = ''
        # Create htpasswd file
        HTPASSWD_FILE="/var/lib/cistern/auth/htpasswd"
        
        # Clear existing file
        > "$HTPASSWD_FILE"
        
        # Add users from configuration
        ${concatStringsSep "\n" (mapAttrsToList (user: hash: ''
          echo "${user}:${hash}" >> "$HTPASSWD_FILE"
        '') config.cistern.auth.users)}
        
        # Set proper permissions
        chown nginx:nginx "$HTPASSWD_FILE"
        chmod 640 "$HTPASSWD_FILE"
        
        # Create default user if no users configured
        if [ ! -s "$HTPASSWD_FILE" ]; then
          echo "Creating default admin user with secure password..."
          
          # Check for agenix secret first
          if [ -f "/run/agenix/admin-password" ]; then
            DEFAULT_PASSWORD=$(cat "/run/agenix/admin-password")
            echo "Using agenix-encrypted admin password"
          # Check for existing plain text password (migration mode)
          elif [ -f "/var/lib/cistern/auth/admin-password.txt" ]; then
            ${lib.optionalString (config.cistern.secrets.enable && !config.cistern.secrets.allowPlainText) ''
              echo "ERROR: Plain text admin password found but allowPlainText=false!"
              echo "ERROR: Please migrate admin password to agenix before disabling plain text fallback"
              exit 1
            ''}
            DEFAULT_PASSWORD=$(cat "/var/lib/cistern/auth/admin-password.txt")
            echo "Using existing plain text admin password (migration pending)"
            ${lib.optionalString (config.cistern.secrets.enable && config.cistern.secrets.enableSecurityWarnings) ''
              echo "SECURITY WARNING: Using plain text admin password" | wall
            ''}
          else
            # Generate new password
            DEFAULT_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 16)
            
            ${lib.optionalString (config.cistern.secrets.enable && !config.cistern.secrets.allowPlainText) ''
              echo "ERROR: No encrypted admin password found and plain text generation disabled!"
              exit 1
            ''}
            
            # Save password in plain text (for migration compatibility)
            PASSWORD_FILE="/var/lib/cistern/auth/admin-password.txt"
            echo "$DEFAULT_PASSWORD" > "$PASSWORD_FILE"
            chmod 600 "$PASSWORD_FILE"
            chown root:root "$PASSWORD_FILE"
            echo "Generated new admin password (plain text - needs migration to agenix)"
            ${lib.optionalString (config.cistern.secrets.enable && config.cistern.secrets.enableSecurityWarnings) ''
              echo "SECURITY WARNING: Generated plain text admin password - migrate to agenix ASAP" | wall
            ''}
          fi
          
          # Create bcrypt hash with cost factor 10 (htpasswd -B uses bcrypt)
          ${pkgs.apacheHttpd}/bin/htpasswd -bBC 10 "$HTPASSWD_FILE" admin "$DEFAULT_PASSWORD"
          chown nginx:nginx "$HTPASSWD_FILE"
          chmod 640 "$HTPASSWD_FILE"
          
          echo "==============================================="
          echo "Default admin credentials created:"
          echo "Username: admin"
          if [ -f "/run/agenix/admin-password" ]; then
            echo "Password: Stored securely in agenix"
            echo "To view: sudo cat /run/agenix/admin-password"
          else
            echo "Password: $DEFAULT_PASSWORD"
            echo "Password saved to: /var/lib/cistern/auth/admin-password.txt"
            echo "IMPORTANT: Migrate to agenix for security!"
          fi
          echo "==============================================="
          echo "IMPORTANT: Change this password after first login!"
        fi
      '';
    };

    # Note: Nginx configuration is now handled by modules/nginx.nix to prevent conflicts

    # Note: Sonarr and Radarr authentication is handled via nginx proxy
    # The services themselves don't have built-in NixOS authentication options

    # Enhanced security logging (basic auth only)
    systemd.services.auth-monitor = mkIf (config.cistern.auth.method == "basic") {
      description = "Monitor authentication attempts";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "auth-monitor" ''
          #!/usr/bin/env bash
          
          LOG_FILE="/var/lib/cistern/auth/access.log"
          
          # Check nginx access logs for failed auth attempts
          if [ -f /var/log/nginx/access.log ]; then
            # Count failed auth attempts in last hour
            FAILED_ATTEMPTS=$(grep "$(date -d '1 hour ago' '+%d/%b/%Y:%H')" /var/log/nginx/access.log | grep -c "401\|403" || echo 0)
            
            if [ "$FAILED_ATTEMPTS" -gt 10 ]; then
              echo "$(date): WARNING - $FAILED_ATTEMPTS failed auth attempts in last hour" >> "$LOG_FILE"
            fi
          fi
          
          # Log current authenticated sessions
          if [ -f /var/lib/cistern/auth/htpasswd ]; then
            USER_COUNT=$(wc -l < /var/lib/cistern/auth/htpasswd)
            echo "$(date): $USER_COUNT users configured" >> "$LOG_FILE"
          fi
        '';
      };
    };

    systemd.timers.auth-monitor = mkIf (config.cistern.auth.method == "basic") {
      description = "Monitor authentication every 10 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/10";
        Persistent = true;
      };
    };

    # Password generation utility (basic auth only)
    environment.systemPackages = with pkgs; [
      openssl      # for password generation
    ] ++ optionals (config.cistern.auth.method == "basic") [
      apacheHttpd  # for htpasswd
    ];

    # User management script (basic auth only)
    systemd.services.cistern-user-manager = mkIf (config.cistern.auth.method == "basic") {
      description = "Cistern user management service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "user-manager" ''
          #!/usr/bin/env bash
          
          case "''${1:-help}" in
            add)
              if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Usage: $0 add <username> <password>"
                exit 1
              fi
              ${pkgs.apacheHttpd}/bin/htpasswd -bB /var/lib/cistern/auth/htpasswd "$2" "$3"
              systemctl reload nginx
              echo "User $2 added successfully"
              ;;
            remove)
              if [ -z "$2" ]; then
                echo "Usage: $0 remove <username>"
                exit 1
              fi
              ${pkgs.apacheHttpd}/bin/htpasswd -D /var/lib/cistern/auth/htpasswd "$2"
              systemctl reload nginx
              echo "User $2 removed successfully"
              ;;
            list)
              cut -d: -f1 /var/lib/cistern/auth/htpasswd
              ;;
            password)
              if [ -z "$2" ]; then
                echo "Usage: $0 password <username>"
                exit 1
              fi
              
              # For admin user, check if we're using agenix
              if [ "$2" = "admin" ] && [ -f "/run/agenix/admin-password" ]; then
                echo "Admin password is managed by agenix"
                echo "To update, encrypt a new password with age and update the secret"
                echo "Current password can be viewed with: sudo cat /run/agenix/admin-password"
              else
                NEW_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 16)
                ${pkgs.apacheHttpd}/bin/htpasswd -bB /var/lib/cistern/auth/htpasswd "$2" "$NEW_PASSWORD"
                systemctl reload nginx
                echo "New password for $2: $NEW_PASSWORD"
                
                # Save admin password to plain text file if it's the admin user (for migration)
                if [ "$2" = "admin" ]; then
                  echo "$NEW_PASSWORD" > /var/lib/cistern/auth/admin-password.txt
                  chmod 600 /var/lib/cistern/auth/admin-password.txt
                  chown root:root /var/lib/cistern/auth/admin-password.txt
                  echo "Note: Consider migrating to agenix for secure password storage"
                fi
              fi
              ;;
            *)
              echo "Cistern User Manager"
              echo "Usage: $0 {add|remove|list|password} [options]"
              echo "  add <user> <pass> - Add new user"
              echo "  remove <user>     - Remove user"
              echo "  list              - List users"
              echo "  password <user>   - Reset password"
              ;;
          esac
        '';
      };
    };
  };
}