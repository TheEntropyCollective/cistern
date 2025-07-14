{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.cistern.secrets;
in
{
  options.cistern.secrets = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable agenix secrets management";
    };

    secretsPath = lib.mkOption {
      type = lib.types.path;
      default = ../secrets;
      description = "Path to the secrets directory";
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/cistern/age.key";
      description = "Path to the age private key file";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          file = lib.mkOption {
            type = lib.types.path;
            description = "Path to the encrypted secret file";
          };
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Owner of the decrypted secret";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Group of the decrypted secret";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "0400";
            description = "Permissions of the decrypted secret";
          };
        };
      });
      default = {};
      description = "Secrets to be managed by agenix";
    };

    autoGenerate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically generate missing secrets";
    };

    migrationMode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable migration mode to fall back to plain text secrets if encrypted ones don't exist";
    };

    allowPlainText = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow plain text secrets as fallback. Set to false to enforce encrypted secrets only";
    };

    enableSecurityWarnings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable security warnings for plain text secrets";
    };

    enableAccessLogging = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable logging of secret access patterns";
    };

    autoCleanupPlainText = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically remove plain text secrets after successful migration (requires explicit enable)";
    };

    plainTextPaths = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        # Map of secret names to their plain text locations for migration
        "sonarr-api-key" = "/var/lib/media/auto-config/sonarr-api-key.txt";
        "radarr-api-key" = "/var/lib/media/auto-config/radarr-api-key.txt";
        "prowlarr-api-key" = "/var/lib/media/auto-config/prowlarr-api-key.txt";
        "bazarr-api-key" = "/var/lib/media/auto-config/bazarr-api-key.txt";
        "jellyfin-api-key" = "/var/lib/media/auto-config/jellyfin-api-key.txt";
        "sabnzbd-api-key" = "/var/lib/media/auto-config/sabnzbd-api-key.txt";
        "transmission-rpc-password" = "/var/lib/media/auto-config/transmission-rpc-password.txt";
        "admin-password" = "/var/lib/cistern/auth/admin-password.txt";
        "authentik-db-password" = "/var/lib/cistern/authentik/db-password";
        "authentik-admin-password" = "/var/lib/cistern/authentik/admin-password";
        "authentik-smtp-password" = "/var/lib/cistern/authentik/smtp-password";
        "authentik-secret-key" = "/var/lib/cistern/authentik/secret-key";
      };
      description = "Paths to plain text secrets for migration";
    };
  };

  config = lib.mkIf cfg.enable {
    # Import agenix module
    age = {
      identityPaths = [ cfg.ageKeyFile ];
      secrets = lib.mapAttrs (name: secret: {
        inherit (secret) file owner group mode;
      }) cfg.secrets;
    };

    # Ensure age key directory exists
    systemd.tmpfiles.rules = [
      "d /etc/cistern 0755 root root -"
    ];

    # Helper scripts
    environment.systemPackages = with pkgs; [
      # Secret generation tool
      (writeScriptBin "cistern-secret-gen" ''
        #!${stdenv.shell}
        set -euo pipefail

        SECRET_TYPE="''${1:-password}"
        LENGTH="''${2:-32}"

        case "$SECRET_TYPE" in
          password)
            ${openssl}/bin/openssl rand -base64 "$LENGTH" | tr -d '\n'
            ;;
          api-key)
            ${openssl}/bin/openssl rand -hex "$LENGTH"
            ;;
          token)
            ${openssl}/bin/openssl rand -urlsafe -base64 "$LENGTH" | tr -d '\n='
            ;;
          *)
            echo "Unknown secret type: $SECRET_TYPE" >&2
            echo "Usage: cistern-secret-gen [password|api-key|token] [length]" >&2
            exit 1
            ;;
        esac
      '')
      
      # Migration detection tool
      (writeScriptBin "cistern-secrets-check" ''
        #!${stdenv.shell}
        set -euo pipefail

        echo "Cistern Secrets Migration Status"
        echo "================================"
        echo

        PLAIN_COUNT=0
        ENCRYPTED_COUNT=0
        MISSING_COUNT=0

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: ''
          echo -n "Checking ${name}... "
          if [ -f "${path}" ]; then
            echo "PLAIN TEXT (needs migration)"
            PLAIN_COUNT=$((PLAIN_COUNT + 1))
          elif [ -f "/run/agenix/${name}" ]; then
            echo "ENCRYPTED (migrated)"
            ENCRYPTED_COUNT=$((ENCRYPTED_COUNT + 1))
          else
            echo "MISSING"
            MISSING_COUNT=$((MISSING_COUNT + 1))
          fi
        '') cfg.plainTextPaths)}

        echo
        echo "Summary:"
        echo "  Plain text secrets: $PLAIN_COUNT"
        echo "  Encrypted secrets: $ENCRYPTED_COUNT"
        echo "  Missing secrets: $MISSING_COUNT"
        
        if [ $PLAIN_COUNT -gt 0 ]; then
          echo
          echo "Migration needed! Run 'cistern-secrets-migrate' to encrypt plain text secrets."
          exit 1
        fi
      '')
      
      # Enhanced secrets status command
      (writeScriptBin "cistern-secrets-status" ''
        #!${stdenv.shell}
        set -euo pipefail

        # Colors
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'

        echo "Cistern Secrets Management Status"
        echo "================================="
        echo

        # Check age key
        echo -e "${BLUE}Age Key Status:${NC}"
        if [ -f "${cfg.ageKeyFile}" ]; then
          echo -e "  Private key: ${GREEN}✓${NC} Exists"
          if [ -f "/etc/cistern/age.pub" ]; then
            echo -e "  Public key:  ${GREEN}✓${NC} $(cat /etc/cistern/age.pub | cut -c1-20)..."
          else
            echo -e "  Public key:  ${YELLOW}⚠${NC} Not found (run generate-age-keys.sh)"
          fi
        else
          echo -e "  Private key: ${RED}✗${NC} Missing"
          echo -e "  Public key:  ${RED}✗${NC} Missing"
          echo
          echo "  Run: sudo cistern-secret-gen-keys"
        fi

        echo
        echo -e "${BLUE}Secret Status:${NC}"
        echo "─────────────────────────────────────────────"
        printf "%-30s %-15s %s\n" "Secret Name" "Status" "Location"
        echo "─────────────────────────────────────────────"

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: ''
          printf "%-30s " "${name}"
          
          # Check encrypted version
          if [ -f "${cfg.secretsPath}/${name}.age" ]; then
            if [ -f "/run/agenix/${name}" ]; then
              printf "${GREEN}%-15s${NC} %s\n" "ENCRYPTED" "/run/agenix/${name}"
            else
              printf "${YELLOW}%-15s${NC} %s\n" "ENCRYPTED*" "${cfg.secretsPath}/${name}.age"
            fi
          elif [ -f "${path}" ]; then
            printf "${RED}%-15s${NC} %s\n" "PLAIN TEXT" "${path}"
          else
            printf "${RED}%-15s${NC} %s\n" "MISSING" "-"
          fi
        '') cfg.plainTextPaths)}

        echo
        echo "─────────────────────────────────────────────"
        echo "* = Encrypted but not deployed to runtime"
        echo

        # Migration progress
        TOTAL=$((${toString (builtins.length (builtins.attrNames cfg.plainTextPaths))}))
        ENCRYPTED=$(find ${cfg.secretsPath} -name "*.age" 2>/dev/null | wc -l || echo 0)
        PROGRESS=$((ENCRYPTED * 100 / TOTAL))

        echo -e "${BLUE}Migration Progress:${NC}"
        echo -n "["
        
        # Progress bar
        BAR_WIDTH=50
        FILLED=$((PROGRESS * BAR_WIDTH / 100))
        for i in $(seq 1 $BAR_WIDTH); do
          if [ $i -le $FILLED ]; then
            echo -n "="
          else
            echo -n "-"
          fi
        done
        
        echo "] $PROGRESS% ($ENCRYPTED/$TOTAL)"
        echo

        # Recommendations
        if [ $PROGRESS -lt 100 ]; then
          echo -e "${YELLOW}Recommendations:${NC}"
          echo "  • Run 'sudo cistern-secrets-migrate-all' to encrypt remaining secrets"
          echo "  • Or use 'sudo ${cfg.secretsPath}/../scripts/migrate-all-secrets.sh'"
        else
          echo -e "${GREEN}All secrets are encrypted!${NC}"
          if [ $ENCRYPTED -gt $(find /run/agenix -type f 2>/dev/null | wc -l || echo 0) ]; then
            echo
            echo -e "${YELLOW}Note:${NC} Some encrypted secrets are not deployed yet."
            echo "      Run deployment to activate them."
          fi
        fi
      '')
    ];

    # Auto-generation service for missing secrets
    systemd.services.cistern-secrets-init = lib.mkIf cfg.autoGenerate {
      description = "Initialize missing Cistern secrets";
      wantedBy = [ "multi-user.target" ];
      before = [ "media-server.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Check if age key exists
        if [ ! -f "${cfg.ageKeyFile}" ]; then
          echo "Generating age key..."
          mkdir -p $(dirname "${cfg.ageKeyFile}")
          ${pkgs.age}/bin/age-keygen -o "${cfg.ageKeyFile}"
          chmod 600 "${cfg.ageKeyFile}"
        fi

        # Initialize missing secrets (placeholder for future implementation)
        echo "Secrets initialization complete"
      '';
    };

    # Security monitoring service
    systemd.services.cistern-secrets-monitor = lib.mkIf cfg.enableAccessLogging {
      description = "Monitor secret access patterns";
      after = [ "agenix.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      
      script = ''
        LOG_FILE="/var/log/cistern/secrets-access.log"
        SECURITY_LOG="/var/log/cistern/secrets-security.log"
        
        mkdir -p $(dirname "$LOG_FILE")
        
        # Log current secret status
        echo "[$(date)] Secret access monitoring started" >> "$LOG_FILE"
        
        # Check for plain text secrets and log warnings
        ${lib.optionalString cfg.enableSecurityWarnings ''
          PLAIN_TEXT_FOUND=0
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: ''
            if [ -f "${path}" ]; then
              echo "[$(date)] WARNING: Plain text secret found: ${name} at ${path}" >> "$SECURITY_LOG"
              PLAIN_TEXT_FOUND=$((PLAIN_TEXT_FOUND + 1))
              
              # Check file permissions
              PERMS=$(stat -c %a "${path}" 2>/dev/null || echo "unknown")
              if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
                echo "[$(date)] CRITICAL: Insecure permissions on ${path}: $PERMS" >> "$SECURITY_LOG"
              fi
            fi
          '') cfg.plainTextPaths)}
          
          if [ $PLAIN_TEXT_FOUND -gt 0 ]; then
            echo "[$(date)] SECURITY WARNING: $PLAIN_TEXT_FOUND plain text secrets detected!" | wall
            
            ${lib.optionalString (!cfg.allowPlainText) ''
              echo "[$(date)] CRITICAL: Plain text secrets found but allowPlainText=false. Services may fail!" >> "$SECURITY_LOG"
            ''}
          fi
        ''}
        
        # Check for missing encrypted secrets
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: secret: ''
          if [ ! -f "${secret.file}" ] && [ ! -f "/run/agenix/${name}" ]; then
            echo "[$(date)] WARNING: Missing encrypted secret: ${name}" >> "$SECURITY_LOG"
          fi
        '') cfg.secrets)}
        
        # Monitor secret file access (using inotify if available)
        if command -v inotifywait >/dev/null 2>&1; then
          echo "[$(date)] Starting inotify monitoring for secret access" >> "$LOG_FILE"
          
          # Monitor agenix runtime secrets
          for secret in /run/agenix/*; do
            if [ -f "$secret" ]; then
              inotifywait -m -e access --format '%T %f accessed' --timefmt '%Y-%m-%d %H:%M:%S' "$secret" >> "$LOG_FILE" 2>&1 &
            fi
          done
          
          # Monitor plain text secrets if they exist
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: ''
            if [ -f "${path}" ]; then
              inotifywait -m -e access --format '%T ${name} (PLAIN TEXT) accessed from ${path}' --timefmt '%Y-%m-%d %H:%M:%S' "${path}" >> "$LOG_FILE" 2>&1 &
            fi
          '') cfg.plainTextPaths)}
        fi
      '';
    };

    # Periodic security audit timer
    systemd.timers.cistern-secrets-audit = lib.mkIf cfg.enableSecurityWarnings {
      description = "Periodic secrets security audit";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    systemd.services.cistern-secrets-audit = lib.mkIf cfg.enableSecurityWarnings {
      description = "Audit secret security status";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      
      script = ''
        AUDIT_LOG="/var/log/cistern/secrets-audit.log"
        mkdir -p $(dirname "$AUDIT_LOG")
        
        echo "=== Cistern Secrets Security Audit - $(date) ===" >> "$AUDIT_LOG"
        
        # Count plain text vs encrypted secrets
        PLAIN_COUNT=0
        ENCRYPTED_COUNT=0
        MISSING_COUNT=0
        INSECURE_COUNT=0
        
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: ''
          if [ -f "${path}" ]; then
            PLAIN_COUNT=$((PLAIN_COUNT + 1))
            
            # Check permissions
            PERMS=$(stat -c %a "${path}" 2>/dev/null || echo "unknown")
            OWNER=$(stat -c %U "${path}" 2>/dev/null || echo "unknown")
            if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
              INSECURE_COUNT=$((INSECURE_COUNT + 1))
              echo "  INSECURE: ${name} has permissions $PERMS (owner: $OWNER)" >> "$AUDIT_LOG"
            fi
            
            # Check for world-readable
            if [ "$PERMS" = "644" ] || [ "$PERMS" = "666" ]; then
              echo "  CRITICAL: ${name} is world-readable!" >> "$AUDIT_LOG"
            fi
          elif [ -f "/run/agenix/${name}" ]; then
            ENCRYPTED_COUNT=$((ENCRYPTED_COUNT + 1))
          else
            MISSING_COUNT=$((MISSING_COUNT + 1))
          fi
        '') cfg.plainTextPaths)}
        
        echo "Summary:" >> "$AUDIT_LOG"
        echo "  Encrypted secrets: $ENCRYPTED_COUNT" >> "$AUDIT_LOG"
        echo "  Plain text secrets: $PLAIN_COUNT" >> "$AUDIT_LOG"
        echo "  Missing secrets: $MISSING_COUNT" >> "$AUDIT_LOG"
        echo "  Insecure permissions: $INSECURE_COUNT" >> "$AUDIT_LOG"
        
        # Check for secrets in environment variables (common security issue)
        echo "" >> "$AUDIT_LOG"
        echo "Checking for secrets in environment..." >> "$AUDIT_LOG"
        
        # Look for common secret patterns in environment
        env | grep -iE '(password|secret|key|token|api)' | grep -vE '(PATH|PUBLIC|LESS)' | while read -r line; do
          VAR_NAME=$(echo "$line" | cut -d= -f1)
          echo "  WARNING: Potential secret in environment: $VAR_NAME" >> "$AUDIT_LOG"
        done
        
        # Generate recommendations
        echo "" >> "$AUDIT_LOG"
        echo "Recommendations:" >> "$AUDIT_LOG"
        
        if [ $PLAIN_COUNT -gt 0 ]; then
          echo "  - Migrate $PLAIN_COUNT plain text secrets to agenix encryption" >> "$AUDIT_LOG"
          echo "  - Run: sudo cistern-secrets-migrate-all" >> "$AUDIT_LOG"
        fi
        
        if [ $INSECURE_COUNT -gt 0 ]; then
          echo "  - Fix permissions on $INSECURE_COUNT secrets" >> "$AUDIT_LOG"
          echo "  - Run: sudo chmod 600 /var/lib/*/auth/*.txt" >> "$AUDIT_LOG"
        fi
        
        if [ $MISSING_COUNT -gt 0 ]; then
          echo "  - Generate $MISSING_COUNT missing secrets" >> "$AUDIT_LOG"
        fi
        
        echo "=== End of audit ===" >> "$AUDIT_LOG"
        
        # Alert if critical issues found
        if [ $INSECURE_COUNT -gt 0 ] || [ $PLAIN_COUNT -gt 0 ]; then
          echo "[$(date)] SECURITY AUDIT: Found $PLAIN_COUNT plain text and $INSECURE_COUNT insecure secrets" | wall
        fi
      '';
    };

    # Automatic plain text cleanup service
    systemd.services.cistern-secrets-cleanup = lib.mkIf cfg.autoCleanupPlainText {
      description = "Automatically cleanup plain text secrets after migration";
      after = [ "agenix.service" "cistern-secrets-init.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
      };
      
      script = ''
        CLEANUP_LOG="/var/log/cistern/auto-cleanup.log"
        mkdir -p $(dirname "$CLEANUP_LOG")
        
        echo "[$(date)] Starting automatic plain text secrets cleanup" >> "$CLEANUP_LOG"
        
        # Check if all secrets are migrated
        ALL_MIGRATED=true
        
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: ''
          if [ -f "${path}" ] && [ ! -f "/run/agenix/${name}" ]; then
            echo "[$(date)] Cannot cleanup - ${name} not yet migrated to agenix" >> "$CLEANUP_LOG"
            ALL_MIGRATED=false
          fi
        '') cfg.plainTextPaths)}
        
        if [ "$ALL_MIGRATED" = "true" ]; then
          echo "[$(date)] All secrets migrated, proceeding with cleanup" >> "$CLEANUP_LOG"
          
          # Run cleanup script in non-interactive mode
          export DRY_RUN=false
          if [ -x "${pkgs.bash}/bin/bash" ] && [ -f "${../scripts/cleanup-plaintext-secrets.sh}" ]; then
            ${pkgs.bash}/bin/bash ${../scripts/cleanup-plaintext-secrets.sh} >> "$CLEANUP_LOG" 2>&1
            
            if [ $? -eq 0 ]; then
              echo "[$(date)] Automatic cleanup completed successfully" >> "$CLEANUP_LOG"
              
              # Create marker file to prevent repeated cleanup attempts
              touch /var/lib/cistern/.secrets-cleanup-done
            else
              echo "[$(date)] ERROR: Automatic cleanup failed" >> "$CLEANUP_LOG"
            fi
          else
            echo "[$(date)] ERROR: Cleanup script not found" >> "$CLEANUP_LOG"
          fi
        else
          echo "[$(date)] Skipping cleanup - not all secrets are migrated yet" >> "$CLEANUP_LOG"
        fi
      '';
    };

    # Enhanced security validation script
    environment.systemPackages = with pkgs; [
      (writeScriptBin "cistern-secrets-validate" ''
        #!${stdenv.shell}
        set -euo pipefail

        # Colors
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'

        echo -e "${BLUE}=== Cistern Secrets Security Validation ===${NC}"
        echo

        # Check 1: File permissions
        echo -e "${BLUE}Checking file permissions...${NC}"
        PERM_ISSUES=0

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: ''
          if [ -f "${path}" ]; then
            PERMS=$(stat -c %a "${path}" 2>/dev/null || echo "unknown")
            OWNER=$(stat -c %U:%G "${path}" 2>/dev/null || echo "unknown")
            
            if [[ "$PERMS" =~ ^[67][0-9][0-9]$ ]]; then
              echo -e "  ${RED}✗${NC} ${name}: World-readable! (perms=$PERMS, owner=$OWNER)"
              PERM_ISSUES=$((PERM_ISSUES + 1))
            elif [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
              echo -e "  ${YELLOW}⚠${NC} ${name}: Weak permissions (perms=$PERMS, owner=$OWNER)"
              PERM_ISSUES=$((PERM_ISSUES + 1))
            fi
          fi
        '') cfg.plainTextPaths)}

        if [ $PERM_ISSUES -eq 0 ]; then
          echo -e "  ${GREEN}✓${NC} All secret files have secure permissions"
        fi

        # Check 2: Environment variables
        echo
        echo -e "${BLUE}Checking for secrets in environment...${NC}"
        ENV_ISSUES=0

        env | grep -iE '(password|secret|key|token|api)' | grep -vE '(PATH|PUBLIC|LESS|HOSTNAME)' | while read -r line; do
          VAR_NAME=$(echo "$line" | cut -d= -f1)
          VAR_VALUE=$(echo "$line" | cut -d= -f2)
          
          # Check if value looks like a secret (not empty, not a path, contains special chars)
          if [[ ! "$VAR_VALUE" =~ ^/|^$ ]] && [[ "$VAR_VALUE" =~ [a-zA-Z0-9]{8,} ]]; then
            echo -e "  ${YELLOW}⚠${NC} Potential secret in environment: $VAR_NAME"
            ENV_ISSUES=$((ENV_ISSUES + 1))
          fi
        done

        if [ $ENV_ISSUES -eq 0 ]; then
          echo -e "  ${GREEN}✓${NC} No obvious secrets found in environment"
        fi

        # Check 3: Process command lines
        echo
        echo -e "${BLUE}Checking for secrets in process arguments...${NC}"
        PROC_ISSUES=0

        ps aux | grep -iE '(password|secret|key|token|api)' | grep -v grep | grep -v "cistern-secrets-validate" | while read -r line; do
          if [[ "$line" =~ password=|secret=|key=|token=|api.*= ]]; then
            PROC=$(echo "$line" | awk '{print $11}' | cut -d'/' -f4)
            echo -e "  ${RED}✗${NC} Potential secret in process arguments: $PROC"
            PROC_ISSUES=$((PROC_ISSUES + 1))
          fi
        done

        if [ $PROC_ISSUES -eq 0 ]; then
          echo -e "  ${GREEN}✓${NC} No secrets found in process arguments"
        fi

        # Check 4: Migration status
        echo
        echo -e "${BLUE}Checking migration status...${NC}"
        
        ${pkgs.bash}/bin/bash -c 'cistern-secrets-check' || true

        # Check 5: Age key security
        echo
        echo -e "${BLUE}Checking age key security...${NC}"
        
        if [ -f "${cfg.ageKeyFile}" ]; then
          KEY_PERMS=$(stat -c %a "${cfg.ageKeyFile}" 2>/dev/null || echo "unknown")
          KEY_OWNER=$(stat -c %U:%G "${cfg.ageKeyFile}" 2>/dev/null || echo "unknown")
          
          if [ "$KEY_PERMS" = "600" ] || [ "$KEY_PERMS" = "400" ]; then
            echo -e "  ${GREEN}✓${NC} Age key has secure permissions ($KEY_PERMS)"
          else
            echo -e "  ${RED}✗${NC} Age key has insecure permissions: $KEY_PERMS (should be 600)"
          fi
          
          if [[ "$KEY_OWNER" == "root:root" ]]; then
            echo -e "  ${GREEN}✓${NC} Age key owned by root"
          else
            echo -e "  ${YELLOW}⚠${NC} Age key owned by: $KEY_OWNER (should be root:root)"
          fi
        else
          echo -e "  ${RED}✗${NC} Age key not found at ${cfg.ageKeyFile}"
        fi

        # Summary
        echo
        echo -e "${BLUE}=== Summary ===${NC}"
        
        TOTAL_ISSUES=$((PERM_ISSUES + ENV_ISSUES + PROC_ISSUES))
        
        if [ $TOTAL_ISSUES -eq 0 ]; then
          echo -e "${GREEN}All security checks passed!${NC}"
        else
          echo -e "${YELLOW}Found $TOTAL_ISSUES potential security issues${NC}"
          echo
          echo "Recommendations:"
          
          if [ $PERM_ISSUES -gt 0 ]; then
            echo "  - Fix file permissions: sudo chmod 600 /var/lib/*/auth/*.txt"
          fi
          
          if [ $ENV_ISSUES -gt 0 ]; then
            echo "  - Review environment variables and move secrets to files"
          fi
          
          if [ $PROC_ISSUES -gt 0 ]; then
            echo "  - Review service configurations to avoid passing secrets as arguments"
          fi
        fi
      '')
    ];
  };
}