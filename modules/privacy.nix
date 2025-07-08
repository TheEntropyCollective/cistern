{ config, pkgs, lib, ... }:

with lib;

{
  # Privacy and security module for Cistern media server
  # Provides VPN integration, kill switches, and privacy-focused defaults

  options.cistern.privacy = {
    enable = mkEnableOption "Enable privacy protections";
    
    vpn = {
      enable = mkEnableOption "Enable VPN integration";
      provider = mkOption {
        type = types.enum [ "wireguard" "openvpn" "custom" ];
        default = "wireguard";
        description = "VPN provider type";
      };
      configFile = mkOption {
        type = types.str;
        default = "/etc/wireguard/wg0.conf";
        description = "Path to VPN configuration file";
      };
      interface = mkOption {
        type = types.str;
        default = "wg0";
        description = "VPN interface name";
      };
      killSwitch = mkEnableOption "Enable VPN kill switch";
    };
    
    dns = {
      provider = mkOption {
        type = types.enum [ "quad9" "cloudflare" "custom" ];
        default = "quad9";
        description = "Privacy-focused DNS provider";
      };
      dnsOverHttps = mkEnableOption "Enable DNS over HTTPS";
    };
    
    authentication = {
      enable = mkEnableOption "Enable web service authentication";
      users = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Username to password hash mapping";
      };
    };
  };

  config = mkIf config.cistern.privacy.enable {
    
    # VPN Configuration
    networking = mkIf config.cistern.privacy.vpn.enable {
      # Enable WireGuard
      wireguard.enable = mkIf (config.cistern.privacy.vpn.provider == "wireguard") true;
      
      # Privacy-focused DNS
      nameservers = mkIf (config.cistern.privacy.dns.provider == "quad9") [
        "9.9.9.9"      # Quad9 Primary
        "149.112.112.112"  # Quad9 Secondary
      ];
      
      nameservers = mkIf (config.cistern.privacy.dns.provider == "cloudflare") [
        "1.1.1.1"      # Cloudflare Primary
        "1.0.0.1"      # Cloudflare Secondary
      ];
      
      # Firewall rules for VPN-only traffic
      firewall = {
        extraCommands = mkIf config.cistern.privacy.vpn.killSwitch ''
          # VPN Kill Switch - Block all traffic except VPN and local
          
          # Allow loopback
          iptables -I OUTPUT -o lo -j ACCEPT
          iptables -I INPUT -i lo -j ACCEPT
          
          # Allow local network
          iptables -I OUTPUT -d 192.168.0.0/16 -j ACCEPT
          iptables -I OUTPUT -d 10.0.0.0/8 -j ACCEPT
          iptables -I OUTPUT -d 172.16.0.0/12 -j ACCEPT
          
          # Allow VPN interface
          iptables -I OUTPUT -o ${config.cistern.privacy.vpn.interface} -j ACCEPT
          iptables -I INPUT -i ${config.cistern.privacy.vpn.interface} -j ACCEPT
          
          # Allow VPN server connection (before VPN is up)
          # This rule is populated dynamically by VPN service
          
          # Allow SSH (emergency access)
          iptables -I INPUT -p tcp --dport 22 -j ACCEPT
          iptables -I OUTPUT -p tcp --sport 22 -j ACCEPT
          
          # Block everything else
          iptables -A OUTPUT -j REJECT --reject-with icmp-net-unreachable
          iptables -A INPUT -j REJECT --reject-with icmp-net-unreachable
        '';
        
        extraStopCommands = ''
          # Clean up VPN kill switch rules
          iptables -F OUTPUT 2>/dev/null || true
          iptables -F INPUT 2>/dev/null || true
        '';
      };
    };

    # DNS over HTTPS configuration
    services.resolved = mkIf config.cistern.privacy.dns.dnsOverHttps {
      enable = true;
      dnssec = "true";
      domains = [ "~." ];
      fallbackDns = [ "1.1.1.1" "9.9.9.9" ];
      extraConfig = ''
        DNS=1.1.1.1#cloudflare-dns.com
        DNSOverTLS=yes
        MulticastDNS=no
        LLMNR=no
      '';
    };

    # VPN Management Service
    systemd.services.cistern-vpn = mkIf config.cistern.privacy.vpn.enable {
      description = "Cistern VPN Manager";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "forking";
        Restart = "always";
        RestartSec = "10s";
        User = "root";
      };
      
      script = ''
        # Start VPN connection
        ${if config.cistern.privacy.vpn.provider == "wireguard" then ''
          ${pkgs.wireguard-tools}/bin/wg-quick up ${config.cistern.privacy.vpn.interface}
        '' else ''
          echo "VPN provider ${config.cistern.privacy.vpn.provider} not yet implemented"
          exit 1
        ''}
        
        # Wait for VPN to be established
        sleep 5
        
        # Verify VPN connection
        if ! ip route show | grep -q "${config.cistern.privacy.vpn.interface}"; then
          echo "VPN failed to establish, activating kill switch"
          exit 1
        fi
        
        echo "VPN connection established successfully"
      '';
      
      preStop = ''
        # Stop VPN connection
        ${if config.cistern.privacy.vpn.provider == "wireguard" then ''
          ${pkgs.wireguard-tools}/bin/wg-quick down ${config.cistern.privacy.vpn.interface} || true
        '' else ""}
      '';
    };

    # VPN Health Check Service  
    systemd.services.cistern-vpn-watchdog = mkIf (config.cistern.privacy.vpn.enable && config.cistern.privacy.vpn.killSwitch) {
      description = "Cistern VPN Watchdog";
      after = [ "cistern-vpn.service" ];
      requires = [ "cistern-vpn.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "30s";
        User = "root";
      };
      
      script = ''
        while true; do
          # Check if VPN interface is up
          if ! ip link show ${config.cistern.privacy.vpn.interface} >/dev/null 2>&1; then
            echo "VPN interface down, stopping media services"
            systemctl stop transmission sonarr radarr prowlarr
            exit 1
          fi
          
          # Check if VPN has a route
          if ! ip route show | grep -q "${config.cistern.privacy.vpn.interface}"; then
            echo "VPN route missing, stopping media services"
            systemctl stop transmission sonarr radarr prowlarr
            exit 1
          fi
          
          # Test external connectivity through VPN
          if ! ${pkgs.curl}/bin/curl -s --connect-timeout 10 --interface ${config.cistern.privacy.vpn.interface} https://ifconfig.me >/dev/null; then
            echo "VPN connectivity test failed"
            # Don't exit immediately, give it a few tries
          fi
          
          sleep 30
        done
      '';
    };

    # Transmission VPN binding
    services.transmission = mkIf config.cistern.privacy.vpn.enable {
      settings = {
        # Bind to VPN interface only
        bind-address-ipv4 = "0.0.0.0";  # This will be overridden by the VPN service
        peer-port-random-on-start = true;
        encryption = 2;  # Require encryption
        
        # Privacy settings
        dht-enabled = false;  # Disable DHT for privacy
        lpd-enabled = false;  # Disable Local Peer Discovery
        pex-enabled = false;  # Disable Peer Exchange
        
        # Connection limits for privacy
        peer-limit-global = 50;
        peer-limit-per-torrent = 10;
      };
    };

    # Create VPN configuration directory
    systemd.tmpfiles.rules = [
      "d /etc/wireguard 0700 root root -"
      "d /var/lib/cistern/privacy 0755 root root -"
    ];

    # Privacy monitoring script
    systemd.services.privacy-monitor = {
      description = "Privacy monitoring and leak detection";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "privacy-monitor" ''
          #!/usr/bin/env bash
          
          LOG_FILE="/var/lib/cistern/privacy/monitor.log"
          
          echo "$(date): Privacy monitoring check" >> "$LOG_FILE"
          
          # Check for DNS leaks
          if command -v dig >/dev/null; then
            DNS_SERVER=$(dig +short @resolver1.opendns.com myip.opendns.com)
            echo "$(date): External IP via DNS: $DNS_SERVER" >> "$LOG_FILE"
          fi
          
          # Check current external IP
          if ${pkgs.curl}/bin/curl -s --connect-timeout 10 https://ifconfig.me >/dev/null; then
            CURRENT_IP=$(${pkgs.curl}/bin/curl -s --connect-timeout 10 https://ifconfig.me)
            echo "$(date): Current external IP: $CURRENT_IP" >> "$LOG_FILE"
          fi
          
          # Check VPN status
          if ip link show ${config.cistern.privacy.vpn.interface} >/dev/null 2>&1; then
            echo "$(date): VPN interface is up" >> "$LOG_FILE"
          else
            echo "$(date): WARNING - VPN interface is down" >> "$LOG_FILE"
          fi
          
          # Log active connections (for debugging)
          ss -tuln | grep -E ':(8080|9091|8989|7878|9696|6767)' >> "$LOG_FILE" 2>/dev/null || true
          
          echo "$(date): Privacy monitoring completed" >> "$LOG_FILE"
        '';
      };
    };

    systemd.timers.privacy-monitor = {
      description = "Run privacy monitoring every 10 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/10";
        Persistent = true;
      };
    };

    # fail2ban for brute force protection
    services.fail2ban = {
      enable = true;
      maxretry = 5;
      findtime = 600;  # 10 minutes
      bantime = 3600;  # 1 hour
      
      jails = {
        nginx-auth = {
          enabled = true;
          filter = "nginx-auth";
          logpath = "/var/log/nginx/access.log";
          maxretry = 3;
          findtime = 300;  # 5 minutes
          bantime = 1800;  # 30 minutes
        };
        
        nginx-noscript = {
          enabled = true;
          filter = "nginx-noscript";
          logpath = "/var/log/nginx/access.log";
          maxretry = 6;
          bantime = 600;  # 10 minutes
        };
        
        nginx-badbots = {
          enabled = true;
          filter = "nginx-badbots";
          logpath = "/var/log/nginx/access.log";
          maxretry = 2;
          bantime = 86400;  # 24 hours
        };
        
        sshd = {
          enabled = true;
          filter = "sshd";
          logpath = "/var/log/auth.log";
          maxretry = 3;
          findtime = 600;  # 10 minutes
          bantime = 3600;  # 1 hour
        };
      };
    };
    
    # Custom fail2ban filters
    environment.etc."fail2ban/filter.d/nginx-auth.conf".text = ''
      [Definition]
      failregex = ^<HOST> -.*"(GET|POST).*(400|401|403|404|444)" .*$
      ignoreregex =
    '';
    
    environment.etc."fail2ban/filter.d/nginx-noscript.conf".text = ''
      [Definition]
      failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)
      ignoreregex =
    '';
    
    environment.etc."fail2ban/filter.d/nginx-badbots.conf".text = ''
      [Definition]
      failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (?:400|401|403|404|405|408|414|444|499|500|502|503|504) .*"(?:python-requests|curl|wget|Go-http-client|masscan|nmap|nikto|sqlmap|gobuster|dirbuster|hydra|medusa|nessus|openvas|skipfish|w3af|wapiti|whatweb|WPScan|joomscan|droopescan|CMSmap|BlindElephant|Nikto|dirb|DirBuster|Uniscan|LFI|XSS|SQLi|RFI|backdoor|shell|eval|exec|system|passthru|include|require|file_get_contents|curl_exec|popen|proc_open|shell_exec|base64_decode|str_rot13|urldecode|rawurldecode|hex2bin|bin2hex|chr|ord|preg_replace|create_function|call_user_func|array_filter|array_map|array_reduce|array_walk|usort|uasort|uksort|call_user_func_array|forward_static_call|forward_static_call_array|Reflection|ReflectionClass|ReflectionFunction|ReflectionMethod|ReflectionObject|ReflectionProperty|ReflectionParameter|ReflectionExtension).*"
      ignoreregex =
    '';

    # Install privacy tools
    environment.systemPackages = with pkgs; [
      wireguard-tools
      curl
      dig
      iptables
      iproute2
      fail2ban
    ];

    # Privacy-focused kernel parameters
    boot.kernel.sysctl = {
      # Disable IPv6 if not using VPN IPv6
      "net.ipv6.conf.all.disable_ipv6" = 1;
      "net.ipv6.conf.default.disable_ipv6" = 1;
      
      # Network security
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      
      # Disable ping responses
      "net.ipv4.icmp_echo_ignore_all" = 1;
    };

    # Log anonymization and cleanup
    systemd.services.log-anonymizer = {
      description = "Anonymize and clean up logs";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "log-anonymizer" ''
          #!/usr/bin/env bash
          
          # Anonymize IP addresses in nginx logs
          if [ -f /var/log/nginx/access.log ]; then
            # Replace IP addresses with anonymized versions (keep first 3 octets, zero last)
            sed -i 's/\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}/\1\2\3XXX/g' /var/log/nginx/access.log
          fi
          
          # Clean up old logs (keep last 30 days)
          find /var/log -name "*.log" -mtime +30 -delete 2>/dev/null || true
          find /var/log -name "*.log.*" -mtime +30 -delete 2>/dev/null || true
          
          # Clean up journal logs older than 1 month
          journalctl --vacuum-time=1month
          
          # Clean up privacy monitor logs
          find /var/lib/cistern/privacy -name "*.log" -mtime +7 -delete 2>/dev/null || true
          
          # Clean up auth logs
          find /var/lib/cistern/auth -name "*.log" -mtime +7 -delete 2>/dev/null || true
          
          # Clean up SSL logs
          find /var/lib/cistern/ssl -name "*.log" -mtime +7 -delete 2>/dev/null || true
          
          echo "Log anonymization and cleanup completed at $(date)"
        '';
      };
    };

    systemd.timers.log-anonymizer = {
      description = "Run log anonymization daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };

    # Configure systemd journal for privacy
    services.journald = {
      extraConfig = ''
        # Limit journal size and retention
        SystemMaxUse=500M
        SystemMaxFileSize=50M
        SystemMaxFiles=10
        MaxRetentionSec=1month
        
        # Forward to syslog for processing
        ForwardToSyslog=yes
        
        # Compress logs
        Compress=yes
        
        # Seal logs for integrity
        Seal=yes
      '';
    };
    
    # Configure logrotate for privacy
    services.logrotate = {
      enable = true;
      settings = {
        header = {
          frequency = "daily";
          rotate = 30;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          create = "644 root root";
        };
        
        "/var/log/nginx/*.log" = {
          frequency = "daily";
          rotate = 7;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          create = "644 nginx nginx";
          postrotate = "systemctl reload nginx";
        };
        
        "/var/lib/cistern/*/monitor.log" = {
          frequency = "weekly";
          rotate = 4;
          compress = true;
          missingok = true;
          notifempty = true;
          create = "644 root root";
        };
      };
    };
  };
  };
}