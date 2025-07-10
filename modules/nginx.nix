{ config, pkgs, lib, ... }:

with lib;

{
  # Centralized nginx configuration for Cistern
  # Consolidates all nginx config to prevent module conflicts

  config = mkIf config.cistern.auth.enable {
    
    # Enhanced nginx configuration
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      
      # Consolidated nginx configuration
      appendConfig = let
        # Define security headers with proper quoting
        securityHeaders = if config.cistern.ssl.enable then ''
          add_header Strict-Transport-Security "max-age=63072000" always;
          add_header X-Frame-Options "DENY" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-XSS-Protection "1" always;
          add_header Referrer-Policy "no-referrer-when-downgrade" always;
          add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
        '' else "";
        
        sslConfig = if config.cistern.ssl.enable then ''
          ssl_protocols TLSv1.2 TLSv1.3;
          ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
          ssl_prefer_server_ciphers off;
          ssl_session_cache shared:SSL:10m;
          ssl_session_timeout 1d;
          ssl_session_tickets off;
          ssl_stapling on;
          ssl_stapling_verify on;
        '' else "";
      in ''
        # Rate limiting for authentication
        limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/m;
        limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
        
        # SSL Configuration (when SSL is enabled)
        ${sslConfig}
        
        # Security headers (when SSL is enabled)
        ${securityHeaders}
        
        # Define auth locations
        map $request_uri $auth_required {
          default 1;
          ~^/auth/login 0;
          ~^/auth/logout 0;
          ~^/health 0;
          ${optionalString (config.cistern.auth.method == "authentik") ''~^/outpost.goauthentik.io 0;''}
        }
        
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
          forceSSL = config.cistern.ssl.enable;
          sslCertificate = mkIf (config.cistern.ssl.enable && config.cistern.ssl.selfSigned) "/var/lib/cistern/ssl/certs/${config.cistern.ssl.domain}.crt";
          sslCertificateKey = mkIf (config.cistern.ssl.enable && config.cistern.ssl.selfSigned) "/var/lib/cistern/ssl/private/${config.cistern.ssl.domain}.key";
          enableACME = mkIf config.cistern.ssl.enable config.cistern.ssl.acme.enable;
          
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
            
            # ACME challenge location (when ACME is enabled)
            "/.well-known/acme-challenge" = mkIf (config.cistern.ssl.enable && config.cistern.ssl.acme.enable) {
              root = "/var/lib/acme/acme-challenge";
            };
          };
        };
      };
    };
  };
}