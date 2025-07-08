{ config, pkgs, lib, ... }:

with lib;

{
  # NoiseFS with Private IPFS Integration for Cistern
  # Provides distributed anonymized storage across Cistern fleet

  options.cistern.noisefs = {
    enable = mkEnableOption "Enable NoiseFS with private IPFS storage";
    
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/noisefs";
      description = "NoiseFS data directory";
    };
    
    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/media/noisefs";
      description = "FUSE mount point for NoiseFS";
    };
    
    ipfs = {
      networkMode = mkOption {
        type = types.enum [ "private" "public" ];
        default = "private";
        description = "IPFS network mode: private (fleet-only) or public (global IPFS network)";
      };
      
      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/ipfs";
        description = "IPFS data directory";
      };
      
      swarmKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Private IPFS swarm key (only used in private mode, leave null to auto-generate)";
      };
      
      apiPort = mkOption {
        type = types.int;
        default = 5001;
        description = "IPFS API port";
      };
      
      gatewayPort = mkOption {
        type = types.int;
        default = 8081;
        description = "IPFS gateway port";
      };
      
      swarmPort = mkOption {
        type = types.int;
        default = 4001;
        description = "IPFS swarm port";
      };
      
      bootstrapPeers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of bootstrap peer addresses for private network";
      };
    };
    
    noisefs = {
      webPort = mkOption {
        type = types.int;
        default = 8082;
        description = "NoiseFS web UI port";
      };
      
      blockSize = mkOption {
        type = types.int;
        default = 131072; # 128KB
        description = "Block size for file chunking";
      };
    };
    
    fleet = {
      servers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of server IPs in the Cistern fleet (exclusive peers in private mode, additional peers in public mode)";
      };
    };
  };

  config = mkIf config.cistern.noisefs.enable {
    
    # System packages
    environment.systemPackages = with pkgs; [
      go_1_21
      kubo # IPFS implementation
      fuse
      git
    ];

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${config.cistern.noisefs.dataDir} 0755 noisefs noisefs -"
      "d ${config.cistern.noisefs.ipfs.dataDir} 0755 ipfs ipfs -"
      "d ${config.cistern.noisefs.mountPoint} 0755 noisefs noisefs -"
      "d /var/lib/cistern/noisefs 0755 noisefs noisefs -"
    ];

    # Create system users
    users.users.ipfs = {
      isSystemUser = true;
      group = "ipfs";
      home = config.cistern.noisefs.ipfs.dataDir;
      createHome = true;
    };

    users.users.noisefs = {
      isSystemUser = true;
      group = "noisefs";
      home = config.cistern.noisefs.dataDir;
      createHome = true;
      extraGroups = [ "fuse" ];
    };

    users.groups.ipfs = {};
    users.groups.noisefs = {};

    # IPFS initialization and private network setup
    systemd.services.ipfs-init = {
      description = "Initialize IPFS node for private network";
      wantedBy = [ "multi-user.target" ];
      before = [ "ipfs.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "ipfs";
        Group = "ipfs";
        RemainAfterExit = true;
        Environment = "IPFS_PATH=${config.cistern.noisefs.ipfs.dataDir}";
      };
      
      script = ''
        if [ ! -f "${config.cistern.noisefs.ipfs.dataDir}/config" ]; then
          echo "Initializing IPFS node for ${config.cistern.noisefs.ipfs.networkMode} network..."
          ${pkgs.kubo}/bin/ipfs init
          
          # Configure IPFS addresses
          ${pkgs.kubo}/bin/ipfs config Addresses.API /ip4/127.0.0.1/tcp/${toString config.cistern.noisefs.ipfs.apiPort}
          ${pkgs.kubo}/bin/ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/${toString config.cistern.noisefs.ipfs.gatewayPort}
          ${pkgs.kubo}/bin/ipfs config Addresses.Swarm '["/ip4/0.0.0.0/tcp/${toString config.cistern.noisefs.ipfs.swarmPort}"]'
          
          ${if config.cistern.noisefs.ipfs.networkMode == "private" then ''
            # Private network configuration
            echo "Configuring for private network..."
            
            # Remove all default bootstrap nodes (disconnect from public network)
            ${pkgs.kubo}/bin/ipfs bootstrap rm --all
            
            # Add fleet servers as bootstrap peers
            ${concatStringsSep "\n" (map (server: ''
              if [ "${server}" != "$(hostname -I | awk '{print $1}')" ]; then
                echo "Adding bootstrap peer: ${server}"
                # Note: Peer ID will be discovered automatically
                ${pkgs.kubo}/bin/ipfs bootstrap add /ip4/${server}/tcp/${toString config.cistern.noisefs.ipfs.swarmPort} || true
              fi
            '') config.cistern.noisefs.fleet.servers)}
            
            echo "IPFS node initialized for private network"
          '' else ''
            # Public network configuration
            echo "Configuring for public network..."
            
            # Keep default bootstrap nodes for public network access
            echo "Using default public IPFS bootstrap nodes"
            
            # Add fleet servers as additional bootstrap peers
            ${concatStringsSep "\n" (map (server: ''
              if [ "${server}" != "$(hostname -I | awk '{print $1}')" ]; then
                echo "Adding additional fleet peer: ${server}"
                ${pkgs.kubo}/bin/ipfs bootstrap add /ip4/${server}/tcp/${toString config.cistern.noisefs.ipfs.swarmPort} || true
              fi
            '') config.cistern.noisefs.fleet.servers)}
            
            echo "IPFS node initialized for public network with fleet peers"
          ''}
        fi
        
        ${if config.cistern.noisefs.ipfs.networkMode == "private" then ''
          # Generate or set swarm key for private network
          SWARM_KEY_FILE="${config.cistern.noisefs.ipfs.dataDir}/swarm.key"
          if [ ! -f "$SWARM_KEY_FILE" ]; then
            ${if config.cistern.noisefs.ipfs.swarmKey != null then ''
              echo "Using provided swarm key for private network"
              echo "${config.cistern.noisefs.ipfs.swarmKey}" > "$SWARM_KEY_FILE"
            '' else ''
              echo "Generating new swarm key for private network"
              echo -e "/key/swarm/psk/1.0.0/\n/base16/\n$(tr -dc 'a-f0-9' < /dev/urandom | head -c64)" > "$SWARM_KEY_FILE"
              echo "Generated swarm key. Share this key with other fleet members:"
              cat "$SWARM_KEY_FILE"
            ''}
            chmod 600 "$SWARM_KEY_FILE"
            chown ipfs:ipfs "$SWARM_KEY_FILE"
          fi
        '' else ''
          # Ensure no swarm key exists for public network
          SWARM_KEY_FILE="${config.cistern.noisefs.ipfs.dataDir}/swarm.key"
          if [ -f "$SWARM_KEY_FILE" ]; then
            echo "Removing swarm key for public network mode"
            rm -f "$SWARM_KEY_FILE"
          fi
        ''}
      '';
    };

    # IPFS daemon service
    systemd.services.ipfs = {
      description = "IPFS daemon for private network";
      after = [ "network.target" "ipfs-init.service" ];
      requires = [ "ipfs-init.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "notify";
        User = "ipfs";
        Group = "ipfs";
        Restart = "always";
        RestartSec = "10s";
        Environment = [
          "IPFS_PATH=${config.cistern.noisefs.ipfs.dataDir}"
        ] ++ optionals (config.cistern.noisefs.ipfs.networkMode == "private") [
          "LIBP2P_FORCE_PNET=1"  # Force private network (only in private mode)
        ];
        ExecStart = "${pkgs.kubo}/bin/ipfs daemon --enable-gc";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        KillMode = "mixed";
        KillSignal = "SIGINT";
      };
    };

    # NoiseFS build and setup
    systemd.services.noisefs-build = {
      description = "Build NoiseFS from source";
      wantedBy = [ "multi-user.target" ];
      before = [ "noisefs.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "noisefs";
        Group = "noisefs";
        RemainAfterExit = true;
        WorkingDirectory = config.cistern.noisefs.dataDir;
      };
      
      script = ''
        if [ ! -f "${config.cistern.noisefs.dataDir}/bin/noisefs" ]; then
          echo "Building NoiseFS..."
          
          # Clone NoiseFS repository
          if [ ! -d "NoiseFS" ]; then
            ${pkgs.git}/bin/git clone https://github.com/TheEntropyCollective/NoiseFS.git
          fi
          
          cd NoiseFS
          
          # Build NoiseFS binaries
          export GOCACHE="${config.cistern.noisefs.dataDir}/.cache/go-build"
          export GOPATH="${config.cistern.noisefs.dataDir}/go"
          export PATH="${pkgs.go_1_21}/bin:$PATH"
          
          make build
          
          # Copy binaries to expected location
          mkdir -p ${config.cistern.noisefs.dataDir}/bin
          cp bin/* ${config.cistern.noisefs.dataDir}/bin/
          
          # Set permissions
          chmod +x ${config.cistern.noisefs.dataDir}/bin/*
          
          echo "NoiseFS build completed"
        fi
      '';
    };

    # NoiseFS daemon service
    systemd.services.noisefs = {
      description = "NoiseFS daemon";
      after = [ "network.target" "ipfs.service" "noisefs-build.service" ];
      requires = [ "ipfs.service" "noisefs-build.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "noisefs";
        Group = "noisefs";
        Restart = "always";
        RestartSec = "10s";
        WorkingDirectory = "${config.cistern.noisefs.dataDir}/NoiseFS";
        Environment = [
          "NOISEFS_IPFS_API=http://127.0.0.1:${toString config.cistern.noisefs.ipfs.apiPort}"
          "NOISEFS_WEB_PORT=${toString config.cistern.noisefs.noisefs.webPort}"
          "NOISEFS_BLOCK_SIZE=${toString config.cistern.noisefs.noisefs.blockSize}"
        ];
      };
      
      script = ''
        # Wait for IPFS to be ready
        echo "Waiting for IPFS to be ready..."
        while ! ${pkgs.curl}/bin/curl -s http://127.0.0.1:${toString config.cistern.noisefs.ipfs.apiPort}/api/v0/version >/dev/null; do
          sleep 2
        done
        echo "IPFS is ready"
        
        # Start NoiseFS web server
        exec ${config.cistern.noisefs.dataDir}/bin/noisefs-web
      '';
    };

    # NoiseFS FUSE mount service
    systemd.services.noisefs-mount = {
      description = "Mount NoiseFS filesystem";
      after = [ "noisefs.service" ];
      requires = [ "noisefs.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "forking";
        User = "noisefs";
        Group = "noisefs";
        Restart = "always";
        RestartSec = "10s";
        WorkingDirectory = "${config.cistern.noisefs.dataDir}/NoiseFS";
      };
      
      script = ''
        # Wait for NoiseFS daemon to be ready
        echo "Waiting for NoiseFS daemon..."
        while ! ${pkgs.curl}/bin/curl -s http://127.0.0.1:${toString config.cistern.noisefs.noisefs.webPort}/health >/dev/null 2>&1; do
          sleep 2
        done
        
        # Mount NoiseFS filesystem
        echo "Mounting NoiseFS at ${config.cistern.noisefs.mountPoint}"
        exec ${config.cistern.noisefs.dataDir}/bin/noisefs-mount ${config.cistern.noisefs.mountPoint}
      '';
      
      preStop = ''
        # Unmount filesystem
        ${pkgs.fuse}/bin/fusermount -u ${config.cistern.noisefs.mountPoint} || true
      '';
    };

    # Create media directories in NoiseFS
    systemd.services.noisefs-media-setup = {
      description = "Setup media directories in NoiseFS";
      after = [ "noisefs-mount.service" ];
      requires = [ "noisefs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "noisefs";
        Group = "noisefs";
        RemainAfterExit = true;
      };
      
      script = ''
        # Wait for mount to be available
        while [ ! -d "${config.cistern.noisefs.mountPoint}" ]; do
          sleep 1
        done
        
        # Create media directory structure
        mkdir -p ${config.cistern.noisefs.mountPoint}/movies
        mkdir -p ${config.cistern.noisefs.mountPoint}/tv
        mkdir -p ${config.cistern.noisefs.mountPoint}/downloads
        mkdir -p ${config.cistern.noisefs.mountPoint}/downloads/complete
        mkdir -p ${config.cistern.noisefs.mountPoint}/downloads/incomplete
        
        # Set proper permissions for media group
        chown -R media:media ${config.cistern.noisefs.mountPoint}
        chmod -R 755 ${config.cistern.noisefs.mountPoint}
        
        echo "NoiseFS media directories created"
      '';
    };

    # NoiseFS monitoring service
    systemd.services.noisefs-monitor = {
      description = "Monitor NoiseFS and IPFS status";
      serviceConfig = {
        Type = "oneshot";
        User = "noisefs";
        ExecStart = pkgs.writeShellScript "noisefs-monitor" ''
          #!/usr/bin/env bash
          
          LOG_FILE="/var/lib/cistern/noisefs/monitor.log"
          
          echo "$(date): NoiseFS monitoring check" >> "$LOG_FILE"
          
          # Check IPFS daemon status
          if ${pkgs.curl}/bin/curl -s http://127.0.0.1:${toString config.cistern.noisefs.ipfs.apiPort}/api/v0/version >/dev/null; then
            echo "$(date): IPFS daemon is running" >> "$LOG_FILE"
            
            # Get peer count
            PEER_COUNT=$(${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:${toString config.cistern.noisefs.ipfs.apiPort}/api/v0/swarm/peers | ${pkgs.jq}/bin/jq '.Peers | length' 2>/dev/null || echo "0")
            echo "$(date): Connected to $PEER_COUNT IPFS peers" >> "$LOG_FILE"
          else
            echo "$(date): ERROR - IPFS daemon not responding" >> "$LOG_FILE"
          fi
          
          # Check NoiseFS web interface
          if ${pkgs.curl}/bin/curl -s http://127.0.0.1:${toString config.cistern.noisefs.noisefs.webPort}/health >/dev/null 2>&1; then
            echo "$(date): NoiseFS web interface is running" >> "$LOG_FILE"
          else
            echo "$(date): ERROR - NoiseFS web interface not responding" >> "$LOG_FILE"
          fi
          
          # Check FUSE mount
          if mountpoint -q ${config.cistern.noisefs.mountPoint}; then
            echo "$(date): NoiseFS filesystem is mounted" >> "$LOG_FILE"
          else
            echo "$(date): ERROR - NoiseFS filesystem not mounted" >> "$LOG_FILE"
          fi
          
          # Check storage usage
          if [ -d "${config.cistern.noisefs.mountPoint}" ]; then
            USAGE=$(df -h ${config.cistern.noisefs.mountPoint} | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
            echo "$(date): Storage usage: $USAGE" >> "$LOG_FILE"
          fi
        '';
      };
    };

    systemd.timers.noisefs-monitor = {
      description = "Monitor NoiseFS every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [
      config.cistern.noisefs.ipfs.swarmPort    # IPFS swarm
      config.cistern.noisefs.noisefs.webPort   # NoiseFS web UI
    ];

    # Add NoiseFS management utilities
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "cistern-noisefs-swarm" ''
        #!/usr/bin/env bash
        
        NETWORK_MODE="${config.cistern.noisefs.ipfs.networkMode}"
        SWARM_KEY_FILE="${config.cistern.noisefs.ipfs.dataDir}/swarm.key"
        
        # Check if we're in private mode
        if [ "$NETWORK_MODE" != "private" ]; then
          echo "ERROR: Swarm key management is only available in private network mode"
          echo "Current mode: $NETWORK_MODE"
          echo "To use private network mode, set cistern.noisefs.ipfs.networkMode = \"private\""
          exit 1
        fi
        
        case "''${1:-help}" in
          generate)
            echo "Generating new swarm key..."
            echo -e "/key/swarm/psk/1.0.0/\n/base16/\n$(tr -dc 'a-f0-9' < /dev/urandom | head -c64)" > "$SWARM_KEY_FILE"
            chmod 600 "$SWARM_KEY_FILE"
            chown ipfs:ipfs "$SWARM_KEY_FILE"
            echo "Swarm key generated at $SWARM_KEY_FILE"
            echo ""
            echo "Share this key with all fleet members:"
            cat "$SWARM_KEY_FILE"
            ;;
          show)
            if [ -f "$SWARM_KEY_FILE" ]; then
              echo "Current swarm key:"
              cat "$SWARM_KEY_FILE"
            else
              echo "Swarm key not found at $SWARM_KEY_FILE"
              exit 1
            fi
            ;;
          set)
            if [ -z "$2" ]; then
              echo "Usage: $0 set <swarm_key_content>"
              echo "Example: $0 set '/key/swarm/psk/1.0.0/'"
              exit 1
            fi
            echo "Setting swarm key..."
            echo "$2" > "$SWARM_KEY_FILE"
            chmod 600 "$SWARM_KEY_FILE"
            chown ipfs:ipfs "$SWARM_KEY_FILE"
            echo "Swarm key updated. Restart IPFS service to apply."
            ;;
          copy-from)
            if [ -z "$2" ]; then
              echo "Usage: $0 copy-from <server_ip>"
              exit 1
            fi
            echo "Copying swarm key from $2..."
            scp "root@$2:${config.cistern.noisefs.ipfs.dataDir}/swarm.key" "$SWARM_KEY_FILE"
            chmod 600 "$SWARM_KEY_FILE"
            chown ipfs:ipfs "$SWARM_KEY_FILE"
            echo "Swarm key copied from $2. Restart IPFS service to apply."
            ;;
          deploy-to)
            if [ -z "$2" ]; then
              echo "Usage: $0 deploy-to <server_ip>"
              exit 1
            fi
            if [ ! -f "$SWARM_KEY_FILE" ]; then
              echo "No swarm key found to deploy"
              exit 1
            fi
            echo "Deploying swarm key to $2..."
            scp "$SWARM_KEY_FILE" "root@$2:${config.cistern.noisefs.ipfs.dataDir}/swarm.key"
            ssh "root@$2" "chmod 600 ${config.cistern.noisefs.ipfs.dataDir}/swarm.key && chown ipfs:ipfs ${config.cistern.noisefs.ipfs.dataDir}/swarm.key"
            echo "Swarm key deployed to $2. Restart IPFS service on remote server."
            ;;
          deploy-fleet)
            if [ ! -f "$SWARM_KEY_FILE" ]; then
              echo "No swarm key found to deploy"
              exit 1
            fi
            ${concatStringsSep "\n            " (map (server: ''
              echo "Deploying to ${server}..."
              scp "$SWARM_KEY_FILE" "root@${server}:${config.cistern.noisefs.ipfs.dataDir}/swarm.key" || echo "Failed to deploy to ${server}"
              ssh "root@${server}" "chmod 600 ${config.cistern.noisefs.ipfs.dataDir}/swarm.key && chown ipfs:ipfs ${config.cistern.noisefs.ipfs.dataDir}/swarm.key" || echo "Failed to set permissions on ${server}"
            '') config.cistern.noisefs.fleet.servers)}
            echo "Swarm key deployed to all fleet members. Restart IPFS services on all servers."
            ;;
          *)
            echo "Cistern NoiseFS Swarm Key Manager"
            echo "Usage: $0 {generate|show|set|copy-from|deploy-to|deploy-fleet}"
            echo "  generate           - Generate a new swarm key"
            echo "  show              - Display current swarm key"
            echo "  set <key>         - Set swarm key from provided content"
            echo "  copy-from <ip>    - Copy swarm key from another server"
            echo "  deploy-to <ip>    - Deploy swarm key to a server"
            echo "  deploy-fleet      - Deploy swarm key to all fleet servers"
            ;;
        esac
      '')
      (pkgs.writeShellScriptBin "cistern-noisefs" ''
        #!/usr/bin/env bash
        
        case "''${1:-help}" in
          status)
            echo "=== NoiseFS Status ==="
            echo "Network Mode: ${config.cistern.noisefs.ipfs.networkMode}"
            ${if config.cistern.noisefs.ipfs.networkMode == "private" then ''
              echo "Private Network: Fleet-only peers"
            '' else ''
              echo "Public Network: Global IPFS + fleet peers"
            ''}
            echo ""
            systemctl status ipfs noisefs noisefs-mount --no-pager
            echo ""
            echo "=== IPFS Peers ==="
            ${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:${toString config.cistern.noisefs.ipfs.apiPort}/api/v0/swarm/peers | ${pkgs.jq}/bin/jq '.Peers[] | .Addr' 2>/dev/null || echo "No peers connected"
            echo ""
            echo "=== Mount Status ==="
            if mountpoint -q ${config.cistern.noisefs.mountPoint}; then
              echo "NoiseFS mounted at ${config.cistern.noisefs.mountPoint}"
              df -h ${config.cistern.noisefs.mountPoint}
            else
              echo "NoiseFS not mounted"
            fi
            ;;
          peers)
            echo "Connected IPFS peers:"
            ${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:${toString config.cistern.noisefs.ipfs.apiPort}/api/v0/swarm/peers | ${pkgs.jq}/bin/jq '.Peers[] | .Addr' 2>/dev/null || echo "No peers connected"
            ;;
          swarm-key)
            echo "Network Mode: ${config.cistern.noisefs.ipfs.networkMode}"
            ${if config.cistern.noisefs.ipfs.networkMode == "private" then ''
              echo "Current swarm key:"
              cat ${config.cistern.noisefs.ipfs.dataDir}/swarm.key 2>/dev/null || echo "Swarm key not found"
            '' else ''
              echo "Swarm key not used in public network mode"
            ''}
            ;;
          restart)
            echo "Restarting NoiseFS services..."
            systemctl restart ipfs noisefs noisefs-mount
            ;;
          logs)
            echo "=== IPFS Logs ==="
            journalctl -u ipfs --no-pager -n 20
            echo ""
            echo "=== NoiseFS Logs ==="
            journalctl -u noisefs --no-pager -n 20
            ;;
          *)
            echo "Cistern NoiseFS Management"
            echo "Usage: $0 {status|peers|swarm-key|restart|logs}"
            echo "  status     - Show service status, network mode, and mount info"
            echo "  peers      - Show connected IPFS peers"
            echo "  swarm-key  - Display swarm key (private mode only)"
            echo "  restart    - Restart all NoiseFS services"
            echo "  logs       - Show recent service logs"
            echo ""
            echo "Network Mode: ${config.cistern.noisefs.ipfs.networkMode}"
            ${if config.cistern.noisefs.ipfs.networkMode == "private" then ''
              echo "  - Private: Fleet-only IPFS network with swarm key"
              echo "  - Use 'cistern-noisefs-swarm' for swarm key management"
            '' else ''
              echo "  - Public: Global IPFS network + fleet peers"
              echo "  - Swarm key management not available in public mode"
            ''}
            ;;
        esac
      '')
    ];
  };
}