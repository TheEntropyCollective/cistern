{ config, pkgs, lib, ... }:

with lib;

{
  # Authentication module for Cistern media services
  # Provides unified login protection for all web interfaces

  options.cistern.auth = {
    enable = mkEnableOption "Enable authentication for web services";
    
    users = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {
        "admin" = "$2y$10$..."; # bcrypt hash
        "user" = "$2y$10$...";
      };
      description = "Username to bcrypt password hash mapping";
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
  };

  config = mkIf config.cistern.auth.enable {
    
    # Generate htpasswd file for nginx auth
    systemd.tmpfiles.rules = [
      "d /var/lib/cistern/auth 0755 nginx nginx -"
    ];

    # Create htpasswd file from user configuration
    systemd.services.cistern-auth-setup = {
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
          echo "Creating default admin user..."
          DEFAULT_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 12)
          echo "$DEFAULT_PASSWORD" > /var/lib/cistern/auth/default-password
          ${pkgs.apacheHttpd}/bin/htpasswd -bc "$HTPASSWD_FILE" admin "$DEFAULT_PASSWORD"
          chown nginx:nginx "$HTPASSWD_FILE"
          chmod 640 "$HTPASSWD_FILE"
          echo "Default admin password: $DEFAULT_PASSWORD"
        fi
      '';
    };

    # Enhanced nginx configuration with authentication
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      
      # Custom configuration for authentication
      appendConfig = ''
        # Rate limiting for authentication
        limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/m;
        limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
        
        # Define auth locations
        map $request_uri $auth_required {
          default 1;
          ~^/auth/login 0;
          ~^/auth/logout 0;
          ~^/health 0;
        }
      '';
      
      virtualHosts = {
        # Main media server interface with authentication
        "${config.networking.hostName}.local" = {
          # SSL configuration will be handled by ssl.nix if enabled
          locations = {
            # Authentication endpoint
            "/auth/login" = {
              return = "200 '<html><body><h1>Login Required</h1><p>Access your media server dashboard to login.</p></body></html>'";
              extraConfig = ''
                add_header Content-Type text/html;
              '';
            };
            
            # Health check endpoint (no auth required)
            "/health" = {
              return = "200 'OK'";
              extraConfig = ''
                add_header Content-Type text/plain;
                access_log off;
              '';
            };
            
            # Dashboard with auth
            "/dashboard" = {
              proxyPass = "http://127.0.0.1:8081";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
              '';
            };
            
            # Jellyfin with auth
            "/" = {
              proxyPass = "http://127.0.0.1:8096";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
                
                # Jellyfin specific headers
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Host $host;
              '';
            };
            
            # Sonarr with auth
            "/sonarr" = {
              proxyPass = "http://127.0.0.1:8989";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
              '';
            };
            
            # Radarr with auth
            "/radarr" = {
              proxyPass = "http://127.0.0.1:7878";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
              '';
            };
            
            # Prowlarr with auth
            "/prowlarr" = {
              proxyPass = "http://127.0.0.1:9696";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
              '';
            };
            
            # Bazarr with auth
            "/bazarr" = {
              proxyPass = "http://127.0.0.1:6767";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
              '';
            };
            
            # Transmission with auth
            "/transmission" = {
              proxyPass = "http://127.0.0.1:9091";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
              '';
            };
            
            # SABnzbd with auth
            "/sabnzbd" = {
              proxyPass = "http://127.0.0.1:8080";
              proxyWebsockets = true;
              extraConfig = ''
                auth_basic "Cistern Media Server";
                auth_basic_user_file /var/lib/cistern/auth/htpasswd;
                limit_req zone=auth burst=10 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
              '';
            };
            
            # API endpoints with rate limiting but no basic auth (apps use API keys)
            "~ ^/(sonarr|radarr|prowlarr|bazarr)/api/" = {
              proxyPass = "http://127.0.0.1:$upstream_port";
              proxyWebsockets = true;
              extraConfig = ''
                limit_req zone=api burst=50 nodelay;
                
                # IP whitelist
                ${concatStringsSep "\n                " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
                deny all;
                
                # Dynamic upstream based on service
                set $upstream_port 8989;
                if ($uri ~ ^/radarr) { set $upstream_port 7878; }
                if ($uri ~ ^/prowlarr) { set $upstream_port 9696; }
                if ($uri ~ ^/bazarr) { set $upstream_port 6767; }
              '';
            };
          };
        };
      };
    };

    # Note: Sonarr and Radarr authentication is handled via nginx proxy
    # The services themselves don't have built-in NixOS authentication options

    # Enhanced security logging
    systemd.services.auth-monitor = {
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

    systemd.timers.auth-monitor = {
      description = "Monitor authentication every 10 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/10";
        Persistent = true;
      };
    };

    # Password generation utility
    environment.systemPackages = with pkgs; [
      apacheHttpd  # for htpasswd
      openssl      # for password generation
    ];

    # User management script
    systemd.services.cistern-user-manager = {
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
              ${pkgs.apacheHttpd}/bin/htpasswd -b /var/lib/cistern/auth/htpasswd "$2" "$3"
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
              NEW_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 12)
              ${pkgs.apacheHttpd}/bin/htpasswd -b /var/lib/cistern/auth/htpasswd "$2" "$NEW_PASSWORD"
              systemctl reload nginx
              echo "New password for $2: $NEW_PASSWORD"
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