{ config, pkgs, lib, ... }:

with lib;

{
  # Centralized nginx configuration for Cistern
  # Consolidates all nginx config to prevent module conflicts

  options.cistern.nginx = {
    securityHeaders = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable security headers in nginx responses";
      };
      
      hsts = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable HTTP Strict Transport Security (HSTS)";
        };
        maxAge = mkOption {
          type = types.int;
          default = 63072000; # 2 years
          description = "HSTS max-age in seconds";
        };
        includeSubdomains = mkOption {
          type = types.bool;
          default = true;
          description = "Include subdomains in HSTS policy";
        };
        preload = mkOption {
          type = types.bool;
          default = false;
          description = "Enable HSTS preloading";
        };
      };
      
      frameOptions = mkOption {
        type = types.enum [ "DENY" "SAMEORIGIN" "ALLOW-FROM" ];
        default = "SAMEORIGIN";
        description = "X-Frame-Options header value";
      };
      
      contentTypeOptions = mkOption {
        type = types.bool;
        default = true;
        description = "Enable X-Content-Type-Options: nosniff";
      };
      
      xssProtection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable X-XSS-Protection header";
      };
      
      referrerPolicy = mkOption {
        type = types.enum [ 
          "no-referrer" 
          "no-referrer-when-downgrade" 
          "same-origin" 
          "origin" 
          "strict-origin" 
          "origin-when-cross-origin" 
          "strict-origin-when-cross-origin" 
          "unsafe-url" 
        ];
        default = "strict-origin-when-cross-origin";
        description = "Referrer-Policy header value";
      };
      
      contentSecurityPolicy = mkOption {
        type = types.str;
        default = "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline' 'unsafe-eval'; frame-ancestors 'self';";
        description = "Content-Security-Policy header value";
      };
      
      permissionsPolicy = mkOption {
        type = types.str;
        default = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()";
        description = "Permissions-Policy header value";
      };
    };
    
    cors = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable CORS headers";
      };
      
      allowedOrigins = mkOption {
        type = types.listOf types.str;
        default = [ "*" ];
        description = "List of allowed origins for CORS";
      };
      
      allowedMethods = mkOption {
        type = types.listOf types.str;
        default = [ "GET" "POST" "PUT" "DELETE" "OPTIONS" ];
        description = "List of allowed HTTP methods for CORS";
      };
      
      allowedHeaders = mkOption {
        type = types.listOf types.str;
        default = [ "Authorization" "Content-Type" "X-Requested-With" ];
        description = "List of allowed headers for CORS";
      };
      
      exposeHeaders = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of headers to expose to the client";
      };
      
      maxAge = mkOption {
        type = types.int;
        default = 86400;
        description = "Max age for CORS preflight cache in seconds";
      };
      
      allowCredentials = mkOption {
        type = types.bool;
        default = true;
        description = "Allow credentials in CORS requests";
      };
    };
  };

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
        
        # Security headers temporarily disabled to resolve nginx config validation issues
        
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
        # Helper function to generate security headers
        securityHeadersConfig = let
          cfg = config.cistern.nginx;
          # Build HSTS header
          hstsHeader = if cfg.securityHeaders.enable && cfg.securityHeaders.hsts.enable then
            let
              hstsValue = "max-age=${toString cfg.securityHeaders.hsts.maxAge}" +
                optionalString cfg.securityHeaders.hsts.includeSubdomains "; includeSubDomains" +
                optionalString cfg.securityHeaders.hsts.preload "; preload";
            in
              ''add_header Strict-Transport-Security "${hstsValue}" always;''
          else "";
          
          # Build other security headers
          otherHeaders = if cfg.securityHeaders.enable then ''
            ${optionalString cfg.securityHeaders.contentTypeOptions ''add_header X-Content-Type-Options "nosniff" always;''}
            ${optionalString cfg.securityHeaders.xssProtection ''add_header X-XSS-Protection "1; mode=block" always;''}
            add_header X-Frame-Options "${cfg.securityHeaders.frameOptions}" always;
            add_header Referrer-Policy "${cfg.securityHeaders.referrerPolicy}" always;
            add_header Content-Security-Policy "${cfg.securityHeaders.contentSecurityPolicy}" always;
            add_header Permissions-Policy "${cfg.securityHeaders.permissionsPolicy}" always;
          '' else "";
          
          # Build CORS headers
          corsHeaders = if cfg.cors.enable then ''
            add_header Access-Control-Allow-Origin "${if length cfg.cors.allowedOrigins == 1 then head cfg.cors.allowedOrigins else "$http_origin"}" always;
            add_header Access-Control-Allow-Methods "${concatStringsSep ", " cfg.cors.allowedMethods}" always;
            add_header Access-Control-Allow-Headers "${concatStringsSep ", " cfg.cors.allowedHeaders}" always;
            ${optionalString (cfg.cors.exposeHeaders != []) ''add_header Access-Control-Expose-Headers "${concatStringsSep ", " cfg.cors.exposeHeaders}" always;''}
            add_header Access-Control-Max-Age "${toString cfg.cors.maxAge}" always;
            ${optionalString cfg.cors.allowCredentials ''add_header Access-Control-Allow-Credentials "true" always;''}
          '' else "";
        in ''
          # Security headers (works for both HTTP and HTTPS)
          ${otherHeaders}
          
          # HSTS header (only for HTTPS)
          ${optionalString config.cistern.ssl.enable hstsHeader}
          
          # CORS headers
          ${corsHeaders}
        '';
        
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
          
          # Apply security headers to the entire virtual host
          extraConfig = ''
            ${securityHeadersConfig}
            
            # Handle CORS preflight requests
            ${optionalString config.cistern.nginx.cors.enable ''
              if ($request_method = 'OPTIONS') {
                add_header Content-Length 0;
                add_header Content-Type text/plain;
                return 204;
              }
            ''}
          '';
          
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
            
            # Dashboard with auth (as default root)
            "/" = {
              proxyPass = "http://127.0.0.1:8081";
              proxyWebsockets = true;
              extraConfig = authConfig "dashboard";
            };
            
            # Dashboard also accessible at /dashboard
            "/dashboard" = {
              proxyPass = "http://127.0.0.1:8081";
              proxyWebsockets = true;
              extraConfig = authConfig "dashboard";
            };
            
            # Jellyfin with auth
            "/jellyfin" = {
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