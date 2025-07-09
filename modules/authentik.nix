{ config, pkgs, lib, ... }:

with lib;

{
  # Authentik SSO identity provider for Cistern media services
  # Provides modern authentication with SSO, 2FA, and centralized user management

  options.cistern.authentik = {
    enable = mkEnableOption "Enable Authentik SSO identity provider";
    
    domain = mkOption {
      type = types.str;
      default = "auth.${config.networking.hostName}.local";
      description = "Domain name for Authentik service";
    };
    
    secretKey = mkOption {
      type = types.str;
      default = "";
      description = "Authentik secret key (leave empty for auto-generation)";
    };
    
    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "PostgreSQL database host";
      };
      
      port = mkOption {
        type = types.int;
        default = 5432;
        description = "PostgreSQL database port";
      };
      
      name = mkOption {
        type = types.str;
        default = "authentik";
        description = "PostgreSQL database name";
      };
      
      user = mkOption {
        type = types.str;
        default = "authentik";
        description = "PostgreSQL database user";
      };
      
      passwordFile = mkOption {
        type = types.str;
        default = "/var/lib/cistern/authentik/db-password";
        description = "Path to file containing database password";
      };
    };
    
    redis = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Redis host for caching and sessions";
      };
      
      port = mkOption {
        type = types.int;
        default = 6379;
        description = "Redis port";
      };
    };
    
    admin = {
      email = mkOption {
        type = types.str;
        default = "admin@${config.networking.hostName}.local";
        description = "Admin user email address";
      };
      
      username = mkOption {
        type = types.str;
        default = "admin";
        description = "Admin username";
      };
      
      passwordFile = mkOption {
        type = types.str;
        default = "/var/lib/cistern/authentik/admin-password";
        description = "Path to file containing admin password";
      };
    };
    
    smtp = {
      enable = mkEnableOption "Enable SMTP for email notifications";
      
      host = mkOption {
        type = types.str;
        default = "";
        description = "SMTP server hostname";
      };
      
      port = mkOption {
        type = types.int;
        default = 587;
        description = "SMTP server port";
      };
      
      user = mkOption {
        type = types.str;
        default = "";
        description = "SMTP username";
      };
      
      passwordFile = mkOption {
        type = types.str;
        default = "/var/lib/cistern/authentik/smtp-password";
        description = "Path to file containing SMTP password";
      };
      
      from = mkOption {
        type = types.str;
        default = "authentik@${config.networking.hostName}.local";
        description = "From email address";
      };
      
      useTLS = mkOption {
        type = types.bool;
        default = true;
        description = "Use TLS for SMTP connection";
      };
    };
    
    outpost = {
      name = mkOption {
        type = types.str;
        default = "cistern-nginx-outpost";
        description = "Name for the nginx outpost";
      };
      
      token = mkOption {
        type = types.str;
        default = "";
        description = "Outpost token (auto-generated if empty)";
      };
    };
  };

  config = mkIf config.cistern.authentik.enable {
    
    # Create authentik user and group
    users.groups.authentik = {};
    users.users.authentik = {
      isSystemUser = true;
      group = "authentik";
      home = "/var/lib/authentik";
      createHome = true;
    };

    # Create directory structure
    systemd.tmpfiles.rules = [
      "d /var/lib/cistern/authentik 0755 authentik authentik -"
      "d /var/lib/cistern/authentik/certs 0700 authentik authentik -"
      "d /var/lib/cistern/authentik/media 0755 authentik authentik -"
      "d /var/lib/cistern/authentik/templates 0755 authentik authentik -"
      "d /var/lib/authentik 0755 authentik authentik -"
    ];

    # PostgreSQL database for Authentik
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_15;
      authentication = pkgs.lib.mkOverride 10 ''
        local authentik authentik trust
        local all postgres trust
        host authentik authentik 127.0.0.1/32 trust
        host authentik authentik ::1/128 trust
      '';
      ensureDatabases = [ config.cistern.authentik.database.name ];
      ensureUsers = [
        {
          name = config.cistern.authentik.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    # Redis for caching and sessions
    services.redis.servers.authentik = {
      enable = true;
      port = config.cistern.authentik.redis.port;
      bind = "127.0.0.1";
      requirePass = null;
    };

    # Generate secrets and passwords
    systemd.services.authentik-init = {
      description = "Initialize Authentik secrets and passwords";
      wantedBy = [ "multi-user.target" ];
      before = [ "authentik-server.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "authentik";
        Group = "authentik";
        RemainAfterExit = true;
      };
      
      script = ''
        # Generate database password if not exists
        if [ ! -f "${config.cistern.authentik.database.passwordFile}" ]; then
          echo "Generating database password..."
          ${pkgs.openssl}/bin/openssl rand -base64 32 > "${config.cistern.authentik.database.passwordFile}"
          chmod 600 "${config.cistern.authentik.database.passwordFile}"
        fi
        
        # Generate admin password if not exists
        if [ ! -f "${config.cistern.authentik.admin.passwordFile}" ]; then
          echo "Generating admin password..."
          ${pkgs.openssl}/bin/openssl rand -base64 16 > "${config.cistern.authentik.admin.passwordFile}"
          chmod 600 "${config.cistern.authentik.admin.passwordFile}"
          echo "Authentik admin password saved to: ${config.cistern.authentik.admin.passwordFile}"
        fi
        
        # Generate secret key if not provided
        if [ ! -f "/var/lib/cistern/authentik/secret-key" ]; then
          echo "Generating Authentik secret key..."
          ${pkgs.openssl}/bin/openssl rand -base64 50 > "/var/lib/cistern/authentik/secret-key"
          chmod 600 "/var/lib/cistern/authentik/secret-key"
        fi
        
        # Generate outpost token if not exists
        if [ ! -f "/var/lib/cistern/authentik/outpost-token" ]; then
          echo "Generating outpost token..."
          ${pkgs.openssl}/bin/openssl rand -hex 32 > "/var/lib/cistern/authentik/outpost-token"
          chmod 600 "/var/lib/cistern/authentik/outpost-token"
        fi
      '';
    };

    # Authentik server service
    systemd.services.authentik-server = {
      description = "Authentik server";
      after = [ "postgresql.service" "redis-authentik.service" "authentik-init.service" ];
      requires = [ "postgresql.service" "redis-authentik.service" "authentik-init.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "exec";
        User = "authentik";
        Group = "authentik";
        Restart = "always";
        RestartSec = "5s";
        
        # Security settings
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/authentik" "/var/lib/cistern/authentik" "/tmp" ];
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
      
      environment = {
        AUTHENTIK_REDIS__HOST = config.cistern.authentik.redis.host;
        AUTHENTIK_REDIS__PORT = toString config.cistern.authentik.redis.port;
        AUTHENTIK_POSTGRESQL__HOST = config.cistern.authentik.database.host;
        AUTHENTIK_POSTGRESQL__PORT = toString config.cistern.authentik.database.port;
        AUTHENTIK_POSTGRESQL__NAME = config.cistern.authentik.database.name;
        AUTHENTIK_POSTGRESQL__USER = config.cistern.authentik.database.user;
        AUTHENTIK_LISTEN__HTTP = "0.0.0.0:9000";
        AUTHENTIK_LISTEN__HTTPS = "0.0.0.0:9443";
        AUTHENTIK_LOG_LEVEL = "info";
        AUTHENTIK_MEDIA_ROOT = "/var/lib/cistern/authentik/media";
        AUTHENTIK_TEMPLATES_ROOT = "/var/lib/cistern/authentik/templates";
      } // optionalAttrs config.cistern.authentik.smtp.enable {
        AUTHENTIK_EMAIL__HOST = config.cistern.authentik.smtp.host;
        AUTHENTIK_EMAIL__PORT = toString config.cistern.authentik.smtp.port;
        AUTHENTIK_EMAIL__USERNAME = config.cistern.authentik.smtp.user;
        AUTHENTIK_EMAIL__FROM = config.cistern.authentik.smtp.from;
        AUTHENTIK_EMAIL__USE_TLS = if config.cistern.authentik.smtp.useTLS then "true" else "false";
      };
      
      script = ''
        # Load secrets
        export AUTHENTIK_SECRET_KEY=$(cat /var/lib/cistern/authentik/secret-key)
        export AUTHENTIK_POSTGRESQL__PASSWORD=$(cat ${config.cistern.authentik.database.passwordFile})
        
        ${optionalString config.cistern.authentik.smtp.enable ''
          if [ -f "${config.cistern.authentik.smtp.passwordFile}" ]; then
            export AUTHENTIK_EMAIL__PASSWORD=$(cat ${config.cistern.authentik.smtp.passwordFile})
          fi
        ''}
        
        # Run database migrations on first start
        if [ ! -f "/var/lib/authentik/.migrated" ]; then
          echo "Running initial database migration..."
          ${pkgs.authentik}/bin/ak migrate
          touch "/var/lib/authentik/.migrated"
        fi
        
        # Start server
        exec ${pkgs.authentik}/bin/ak server
      '';
    };

    # Authentik worker service
    systemd.services.authentik-worker = {
      description = "Authentik worker";
      after = [ "authentik-server.service" ];
      requires = [ "authentik-server.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "exec";
        User = "authentik";
        Group = "authentik";
        Restart = "always";
        RestartSec = "5s";
        
        # Security settings
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/authentik" "/var/lib/cistern/authentik" "/tmp" ];
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
      
      environment = {
        AUTHENTIK_REDIS__HOST = config.cistern.authentik.redis.host;
        AUTHENTIK_REDIS__PORT = toString config.cistern.authentik.redis.port;
        AUTHENTIK_POSTGRESQL__HOST = config.cistern.authentik.database.host;
        AUTHENTIK_POSTGRESQL__PORT = toString config.cistern.authentik.database.port;
        AUTHENTIK_POSTGRESQL__NAME = config.cistern.authentik.database.name;
        AUTHENTIK_POSTGRESQL__USER = config.cistern.authentik.database.user;
        AUTHENTIK_LOG_LEVEL = "info";
        AUTHENTIK_MEDIA_ROOT = "/var/lib/cistern/authentik/media";
        AUTHENTIK_TEMPLATES_ROOT = "/var/lib/cistern/authentik/templates";
      } // optionalAttrs config.cistern.authentik.smtp.enable {
        AUTHENTIK_EMAIL__HOST = config.cistern.authentik.smtp.host;
        AUTHENTIK_EMAIL__PORT = toString config.cistern.authentik.smtp.port;
        AUTHENTIK_EMAIL__USERNAME = config.cistern.authentik.smtp.user;
        AUTHENTIK_EMAIL__FROM = config.cistern.authentik.smtp.from;
        AUTHENTIK_EMAIL__USE_TLS = if config.cistern.authentik.smtp.useTLS then "true" else "false";
      };
      
      script = ''
        # Load secrets
        export AUTHENTIK_SECRET_KEY=$(cat /var/lib/cistern/authentik/secret-key)
        export AUTHENTIK_POSTGRESQL__PASSWORD=$(cat ${config.cistern.authentik.database.passwordFile})
        
        ${optionalString config.cistern.authentik.smtp.enable ''
          if [ -f "${config.cistern.authentik.smtp.passwordFile}" ]; then
            export AUTHENTIK_EMAIL__PASSWORD=$(cat ${config.cistern.authentik.smtp.passwordFile})
          fi
        ''}
        
        # Start worker
        exec ${pkgs.authentik}/bin/ak worker
      '';
    };

    # Initial admin user setup
    systemd.services.authentik-bootstrap = {
      description = "Bootstrap Authentik with admin user";
      after = [ "authentik-server.service" ];
      requires = [ "authentik-server.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "authentik";
        Group = "authentik";
        RemainAfterExit = true;
      };
      
      environment = {
        AUTHENTIK_REDIS__HOST = config.cistern.authentik.redis.host;
        AUTHENTIK_REDIS__PORT = toString config.cistern.authentik.redis.port;
        AUTHENTIK_POSTGRESQL__HOST = config.cistern.authentik.database.host;
        AUTHENTIK_POSTGRESQL__PORT = toString config.cistern.authentik.database.port;
        AUTHENTIK_POSTGRESQL__NAME = config.cistern.authentik.database.name;
        AUTHENTIK_POSTGRESQL__USER = config.cistern.authentik.database.user;
      };
      
      script = ''
        # Load secrets
        export AUTHENTIK_SECRET_KEY=$(cat /var/lib/cistern/authentik/secret-key)
        export AUTHENTIK_POSTGRESQL__PASSWORD=$(cat ${config.cistern.authentik.database.passwordFile})
        
        # Wait for server to be ready
        for i in {1..30}; do
          if ${pkgs.curl}/bin/curl -s http://localhost:9000/if/health/live/ >/dev/null 2>&1; then
            break
          fi
          echo "Waiting for Authentik server to be ready... ($i/30)"
          sleep 5
        done
        
        # Create admin user if not exists
        if ! ${pkgs.authentik}/bin/ak shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); exit(1 if User.objects.filter(username='${config.cistern.authentik.admin.username}').exists() else 0)"; then
          echo "Creating admin user..."
          ADMIN_PASSWORD=$(cat ${config.cistern.authentik.admin.passwordFile})
          ${pkgs.authentik}/bin/ak shell -c "
            from django.contrib.auth import get_user_model
            User = get_user_model()
            User.objects.create_superuser(
                username='${config.cistern.authentik.admin.username}',
                email='${config.cistern.authentik.admin.email}',
                password='$ADMIN_PASSWORD'
            )
            print('Admin user created successfully')
          "
        fi
      '';
    };

    # Nginx configuration for Authentik
    services.nginx = {
      enable = true;
      
      virtualHosts."${config.cistern.authentik.domain}" = {
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:9000";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Forwarded-Uri $request_uri;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection $connection_upgrade;
              proxy_redirect off;
              
              # Buffer settings for large headers
              proxy_buffer_size 128k;
              proxy_buffers 4 256k;
              proxy_busy_buffers_size 256k;
            '';
          };
          
          # Outpost endpoint for forward auth
          "/outpost.goauthentik.io" = {
            proxyPass = "http://127.0.0.1:9000";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Forwarded-Uri $request_uri;
              
              # Auth endpoint specific settings
              auth_request_set $user $upstream_http_remote_user;
              auth_request_set $name $upstream_http_remote_name;
              auth_request_set $email $upstream_http_remote_email;
              auth_request_set $groups $upstream_http_remote_groups;
            '';
          };
        };
      };
    };

    # Management utilities
    environment.systemPackages = with pkgs; [
      authentik
      postgresql
      (writeShellScriptBin "cistern-authentik" ''
        #!/usr/bin/env bash
        
        export AUTHENTIK_SECRET_KEY=$(cat /var/lib/cistern/authentik/secret-key)
        export AUTHENTIK_POSTGRESQL__PASSWORD=$(cat ${config.cistern.authentik.database.passwordFile})
        export AUTHENTIK_POSTGRESQL__HOST=${config.cistern.authentik.database.host}
        export AUTHENTIK_POSTGRESQL__PORT=${toString config.cistern.authentik.database.port}
        export AUTHENTIK_POSTGRESQL__NAME=${config.cistern.authentik.database.name}
        export AUTHENTIK_POSTGRESQL__USER=${config.cistern.authentik.database.user}
        export AUTHENTIK_REDIS__HOST=${config.cistern.authentik.redis.host}
        export AUTHENTIK_REDIS__PORT=${toString config.cistern.authentik.redis.port}
        
        case "''${1:-help}" in
          shell)
            ${authentik}/bin/ak shell
            ;;
          migrate)
            ${authentik}/bin/ak migrate
            ;;
          admin-password)
            echo "Admin password: $(cat ${config.cistern.authentik.admin.passwordFile})"
            echo "Admin username: ${config.cistern.authentik.admin.username}"
            echo "Admin email: ${config.cistern.authentik.admin.email}"
            ;;
          status)
            systemctl status authentik-server authentik-worker
            ;;
          logs)
            journalctl -fu authentik-server authentik-worker
            ;;
          *)
            echo "Cistern Authentik Management"
            echo "Usage: $0 {shell|migrate|admin-password|status|logs}"
            echo "  shell         - Open Django shell"
            echo "  migrate       - Run database migrations"
            echo "  admin-password - Show admin credentials"
            echo "  status        - Show service status"
            echo "  logs          - Show service logs"
            ;;
        esac
      '')
    ];

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [ 9000 9443 ];
  };
}