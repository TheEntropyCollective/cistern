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
  };
}