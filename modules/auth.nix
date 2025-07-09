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
          ${optionalString (config.cistern.auth.method == "authentik") ''~^/outpost.goauthentik.io 0;''}
        }
        
        # Security headers (when SSL is enabled)
        ${optionalString config.cistern.ssl.enable ''
        add_header Strict-Transport-Security "max-age=63072000" always;
        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
        ''}
        
        ${optionalString (config.cistern.auth.method == "authentik") ''
        # Authentik auth subrequest configuration
        # Forward auth endpoint
        location = /outpost.goauthentik.io/auth/nginx {
          internal;
          proxy_pass http://${config.cistern.auth.authentik.domain}/outpost.goauthentik.io/auth/nginx;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header Host $http_host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Uri $request_uri;
          
          # Capture auth headers
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $name $upstream_http_remote_name;
          auth_request_set $email $upstream_http_remote_email;
          auth_request_set $groups $upstream_http_remote_groups;
          
          # Buffer settings for large headers
          proxy_buffer_size 128k;
          proxy_buffers 4 256k;
          proxy_busy_buffers_size 256k;
        }
        
        # Authentik sign-in endpoint
        location @goauthentik_proxy_signin {
          internal;
          add_header Set-Cookie $auth_cookie;
          return 302 /outpost.goauthentik.io/start?rd=$request_uri;
        }
        ''}
      '';
      
      virtualHosts = let
        # Helper function to generate auth configuration
        authConfig = service: 
          if config.cistern.auth.method == "authentik" then ''
            # Authentik forward auth
            auth_request /outpost.goauthentik.io/auth/nginx;
            error_page 401 = @goauthentik_proxy_signin;
            
            # Pass authentication headers to upstream
            auth_request_set $user $upstream_http_remote_user;
            auth_request_set $name $upstream_http_remote_name;
            auth_request_set $email $upstream_http_remote_email;
            auth_request_set $groups $upstream_http_remote_groups;
            proxy_set_header Remote-User $user;
            proxy_set_header Remote-Name $name;
            proxy_set_header Remote-Email $email;
            proxy_set_header Remote-Groups $groups;
            
            # Rate limiting
            limit_req zone=auth burst=10 nodelay;
            
            # IP whitelist
            ${concatStringsSep "\n            " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
            deny all;
          '' else ''
            # Basic authentication
            auth_basic "Cistern Media Server";
            auth_basic_user_file /var/lib/cistern/auth/htpasswd;
            limit_req zone=auth burst=10 nodelay;
            
            # IP whitelist
            ${concatStringsSep "\n            " (map (ip: "allow ${ip};") config.cistern.auth.allowedIPs)}
            deny all;
          '';
      in {
        # Main media server interface with authentication
        "${config.networking.hostName}.local" = {
          # SSL configuration will be handled by ssl.nix if enabled
          locations = {
            # Authentication endpoint
            "/auth/login" = {
              return = "200 '<html><body><h1>Login Required</h1><p>Access your media server dashboard to login.</p></body></html>'";
              extraConfig = ''
                add_header Content-Type "text/html";
              '';
            };
            
            # Health check endpoint (no auth required)
            "/health" = {
              return = "200 'OK'";
              extraConfig = ''
                add_header Content-Type "text/plain";
                access_log off;
              '';
            };
            
            # Dashboard with auth
            "/dashboard" = {
              proxyPass = "http://127.0.0.1:8081";
              proxyWebsockets = true;
              extraConfig = authConfig "dashboard";
            };
            
            # Jellyfin with auth
            "/" = {
              proxyPass = "http://127.0.0.1:8096";
              proxyWebsockets = true;
              extraConfig = ''
                ${authConfig "jellyfin"}
                
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
              extraConfig = authConfig "sonarr";
            };
            
            # Radarr with auth
            "/radarr" = {
              proxyPass = "http://127.0.0.1:7878";
              proxyWebsockets = true;
              extraConfig = authConfig "radarr";
            };
            
            # Prowlarr with auth
            "/prowlarr" = {
              proxyPass = "http://127.0.0.1:9696";
              proxyWebsockets = true;
              extraConfig = authConfig "prowlarr";
            };
            
            # Bazarr with auth
            "/bazarr" = {
              proxyPass = "http://127.0.0.1:6767";
              proxyWebsockets = true;
              extraConfig = authConfig "bazarr";
            };
            
            # Transmission with auth
            "/transmission" = {
              proxyPass = "http://127.0.0.1:9091";
              proxyWebsockets = true;
              extraConfig = authConfig "transmission";
            };
            
            # SABnzbd with auth
            "/sabnzbd" = {
              proxyPass = "http://127.0.0.1:8080";
              proxyWebsockets = true;
              extraConfig = authConfig "sabnzbd";
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