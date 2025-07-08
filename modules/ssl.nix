{ config, pkgs, lib, ... }:

with lib;

{
  # SSL certificate management for Cistern media services
  # Provides automatic certificate generation and management

  options.cistern.ssl = {
    enable = mkEnableOption "Enable SSL certificate management";
    
    domain = mkOption {
      type = types.str;
      default = "${config.networking.hostName}.local";
      description = "Domain name for SSL certificate";
    };
    
    selfSigned = mkOption {
      type = types.bool;
      default = true;
      description = "Generate self-signed certificates";
    };
    
    acme = {
      enable = mkEnableOption "Enable ACME (Let's Encrypt) certificates";
      email = mkOption {
        type = types.str;
        default = "";
        description = "Email for ACME registration";
      };
      server = mkOption {
        type = types.str;
        default = "https://acme-v02.api.letsencrypt.org/directory";
        description = "ACME server URL";
      };
    };
    
    certificateKeySize = mkOption {
      type = types.int;
      default = 2048;
      description = "SSL certificate key size in bits";
    };
    
    certificateValidityDays = mkOption {
      type = types.int;
      default = 365;
      description = "Certificate validity period in days";
    };
  };

  config = mkIf config.cistern.ssl.enable {
    
    # Create SSL directory structure
    systemd.tmpfiles.rules = [
      "d /var/lib/cistern/ssl 0755 nginx nginx -"
      "d /var/lib/cistern/ssl/certs 0700 nginx nginx -"
      "d /var/lib/cistern/ssl/private 0700 nginx nginx -"
    ];

    # Self-signed certificate generation
    systemd.services.cistern-ssl-setup = mkIf config.cistern.ssl.selfSigned {
      description = "Generate SSL certificates for Cistern";
      wantedBy = [ "multi-user.target" ];
      before = [ "nginx.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
      };
      
      script = ''
        CERT_DIR="/var/lib/cistern/ssl"
        CERT_FILE="$CERT_DIR/certs/${config.cistern.ssl.domain}.crt"
        KEY_FILE="$CERT_DIR/private/${config.cistern.ssl.domain}.key"
        
        # Check if certificates already exist and are valid
        if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
          # Check if certificate is still valid for at least 30 days
          if ${pkgs.openssl}/bin/openssl x509 -checkend 2592000 -noout -in "$CERT_FILE" >/dev/null 2>&1; then
            echo "SSL certificate is still valid, skipping generation"
            exit 0
          fi
        fi
        
        echo "Generating new SSL certificate for ${config.cistern.ssl.domain}"
        
        # Generate private key
        ${pkgs.openssl}/bin/openssl genrsa -out "$KEY_FILE" ${toString config.cistern.ssl.certificateKeySize}
        
        # Generate certificate signing request
        ${pkgs.openssl}/bin/openssl req -new -key "$KEY_FILE" -out "$CERT_DIR/certs/${config.cistern.ssl.domain}.csr" -subj "/C=US/ST=State/L=City/O=Cistern/CN=${config.cistern.ssl.domain}"
        
        # Generate self-signed certificate
        ${pkgs.openssl}/bin/openssl x509 -req -in "$CERT_DIR/certs/${config.cistern.ssl.domain}.csr" -signkey "$KEY_FILE" -out "$CERT_FILE" -days ${toString config.cistern.ssl.certificateValidityDays} -extensions v3_req -extfile <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${config.cistern.ssl.domain}
DNS.2 = ${config.networking.hostName}
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 192.168.1.100
EOF
        )
        
        # Set proper permissions
        chown nginx:nginx "$CERT_FILE" "$KEY_FILE"
        chmod 644 "$CERT_FILE"
        chmod 600 "$KEY_FILE"
        
        # Clean up CSR
        rm -f "$CERT_DIR/certs/${config.cistern.ssl.domain}.csr"
        
        echo "SSL certificate generated successfully"
        echo "Certificate: $CERT_FILE"
        echo "Private Key: $KEY_FILE"
        
        # Display certificate info
        ${pkgs.openssl}/bin/openssl x509 -in "$CERT_FILE" -text -noout | grep -A 2 "Subject:"
        ${pkgs.openssl}/bin/openssl x509 -in "$CERT_FILE" -text -noout | grep -A 10 "X509v3 Subject Alternative Name:"
      '';
    };

    # ACME (Let's Encrypt) certificate management
    security.acme = mkIf config.cistern.ssl.acme.enable {
      acceptTerms = true;
      defaults = {
        email = config.cistern.ssl.acme.email;
        server = config.cistern.ssl.acme.server;
      };
      
      certs."${config.cistern.ssl.domain}" = {
        domain = config.cistern.ssl.domain;
        extraDomainNames = [
          config.networking.hostName
        ];
        webroot = "/var/lib/acme/acme-challenge";
        group = "nginx";
        postRun = "systemctl reload nginx";
      };
    };

    # Enhanced nginx configuration with SSL
    services.nginx = {
      enable = true;
      
      # Add SSL configuration
      appendConfig = ''
        # SSL Configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;
        ssl_stapling on;
        ssl_stapling_verify on;
        
        # Security headers
        add_header Strict-Transport-Security "max-age=63072000" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
      '';
      
      virtualHosts."${config.cistern.ssl.domain}" = {
        # HTTP to HTTPS redirect
        addSSL = true;
        forceSSL = true;
        
        # Certificate configuration
        sslCertificate = mkIf config.cistern.ssl.selfSigned "/var/lib/cistern/ssl/certs/${config.cistern.ssl.domain}.crt";
        sslCertificateKey = mkIf config.cistern.ssl.selfSigned "/var/lib/cistern/ssl/private/${config.cistern.ssl.domain}.key";
        
        # ACME certificate (overrides self-signed if enabled)
        enableACME = config.cistern.ssl.acme.enable;
        
        # ACME challenge location
        locations."/.well-known/acme-challenge" = mkIf config.cistern.ssl.acme.enable {
          root = "/var/lib/acme/acme-challenge";
        };
      };
    };

    # Certificate renewal service for self-signed certificates
    systemd.services.cistern-ssl-renewal = mkIf config.cistern.ssl.selfSigned {
      description = "Renew Cistern SSL certificates";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${config.systemd.services.cistern-ssl-setup.script}";
      };
    };

    systemd.timers.cistern-ssl-renewal = mkIf config.cistern.ssl.selfSigned {
      description = "Renew SSL certificates monthly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Certificate monitoring service
    systemd.services.ssl-monitor = {
      description = "Monitor SSL certificate expiration";
      serviceConfig = {
        Type = "oneshot";
        User = "nginx";
        ExecStart = pkgs.writeShellScript "ssl-monitor" ''
          #!/usr/bin/env bash
          
          CERT_FILE="/var/lib/cistern/ssl/certs/${config.cistern.ssl.domain}.crt"
          LOG_FILE="/var/lib/cistern/ssl/monitor.log"
          
          if [ ! -f "$CERT_FILE" ]; then
            echo "$(date): ERROR - SSL certificate not found: $CERT_FILE" >> "$LOG_FILE"
            exit 1
          fi
          
          # Check certificate expiration
          DAYS_UNTIL_EXPIRY=$(${pkgs.openssl}/bin/openssl x509 -checkend 0 -noout -in "$CERT_FILE" 2>/dev/null && echo "valid" || echo "expired")
          
          if [ "$DAYS_UNTIL_EXPIRY" = "expired" ]; then
            echo "$(date): ERROR - SSL certificate has expired" >> "$LOG_FILE"
            exit 1
          fi
          
          # Check if certificate expires within 30 days
          if ! ${pkgs.openssl}/bin/openssl x509 -checkend 2592000 -noout -in "$CERT_FILE" >/dev/null 2>&1; then
            echo "$(date): WARNING - SSL certificate expires within 30 days" >> "$LOG_FILE"
          else
            echo "$(date): SSL certificate is valid" >> "$LOG_FILE"
          fi
          
          # Get certificate details
          EXPIRY_DATE=$(${pkgs.openssl}/bin/openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
          echo "$(date): Certificate expires on: $EXPIRY_DATE" >> "$LOG_FILE"
          
          # Check certificate fingerprint
          FINGERPRINT=$(${pkgs.openssl}/bin/openssl x509 -fingerprint -sha256 -noout -in "$CERT_FILE" | cut -d= -f2)
          echo "$(date): Certificate fingerprint: $FINGERPRINT" >> "$LOG_FILE"
        '';
      };
    };

    systemd.timers.ssl-monitor = {
      description = "Monitor SSL certificates daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # Certificate management utility
    environment.systemPackages = with pkgs; [
      openssl
      (writeShellScriptBin "cistern-ssl" ''
        #!/usr/bin/env bash
        
        CERT_DIR="/var/lib/cistern/ssl"
        DOMAIN="${config.cistern.ssl.domain}"
        
        case "''${1:-help}" in
          info)
            echo "SSL Certificate Information:"
            echo "Domain: $DOMAIN"
            echo "Certificate: $CERT_DIR/certs/$DOMAIN.crt"
            echo "Private Key: $CERT_DIR/private/$DOMAIN.key"
            echo ""
            if [ -f "$CERT_DIR/certs/$DOMAIN.crt" ]; then
              echo "Certificate Details:"
              ${openssl}/bin/openssl x509 -in "$CERT_DIR/certs/$DOMAIN.crt" -text -noout | grep -A 2 "Subject:"
              echo ""
              echo "Validity:"
              ${openssl}/bin/openssl x509 -in "$CERT_DIR/certs/$DOMAIN.crt" -dates -noout
              echo ""
              echo "Fingerprint:"
              ${openssl}/bin/openssl x509 -in "$CERT_DIR/certs/$DOMAIN.crt" -fingerprint -sha256 -noout
            else
              echo "Certificate not found!"
            fi
            ;;
          renew)
            echo "Renewing SSL certificate..."
            systemctl start cistern-ssl-setup
            systemctl reload nginx
            echo "Certificate renewed and nginx reloaded"
            ;;
          verify)
            if [ -f "$CERT_DIR/certs/$DOMAIN.crt" ]; then
              ${openssl}/bin/openssl verify -CAfile "$CERT_DIR/certs/$DOMAIN.crt" "$CERT_DIR/certs/$DOMAIN.crt"
            else
              echo "Certificate not found!"
              exit 1
            fi
            ;;
          *)
            echo "Cistern SSL Certificate Manager"
            echo "Usage: $0 {info|renew|verify}"
            echo "  info   - Show certificate information"
            echo "  renew  - Renew certificate"
            echo "  verify - Verify certificate"
            ;;
        esac
      '')
    ];

    # Open HTTPS port
    networking.firewall.allowedTCPPorts = [ 443 ];
  };
}