#!/usr/bin/env bash
#
# Cistern Plain Text Secrets Cleanup Script
# This script safely removes plain text secrets after verifying successful migration to agenix
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="/var/backups/cistern-secrets-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/cistern/plaintext-cleanup.log"
DRY_RUN=${DRY_RUN:-true}

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Create log directory
mkdir -p $(dirname "$LOG_FILE")

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Plain text secret locations
declare -A PLAIN_TEXT_SECRETS=(
    ["sonarr-api-key"]="/var/lib/media/auto-config/sonarr-api-key.txt"
    ["radarr-api-key"]="/var/lib/media/auto-config/radarr-api-key.txt"
    ["prowlarr-api-key"]="/var/lib/media/auto-config/prowlarr-api-key.txt"
    ["bazarr-api-key"]="/var/lib/media/auto-config/bazarr-api-key.txt"
    ["jellyfin-api-key"]="/var/lib/media/auto-config/jellyfin-api-key.txt"
    ["sabnzbd-api-key"]="/var/lib/media/auto-config/sabnzbd-api-key.txt"
    ["transmission-rpc-password"]="/var/lib/media/auto-config/transmission-rpc-password.txt"
    ["admin-password"]="/var/lib/cistern/auth/admin-password.txt"
    ["authentik-db-password"]="/var/lib/cistern/authentik/db-password"
    ["authentik-admin-password"]="/var/lib/cistern/authentik/admin-password"
    ["authentik-smtp-password"]="/var/lib/cistern/authentik/smtp-password"
    ["authentik-secret-key"]="/var/lib/cistern/authentik/secret-key"
)

echo -e "${BLUE}=== Cistern Plain Text Secrets Cleanup ===${NC}"
echo

# Check if running in dry-run mode
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}Running in DRY-RUN mode. No changes will be made.${NC}"
    echo -e "${YELLOW}To perform actual cleanup, run: DRY_RUN=false $0${NC}"
    echo
fi

log "Starting plain text secrets cleanup (DRY_RUN=$DRY_RUN)"

# Step 1: Validate all secrets are properly migrated
echo -e "${BLUE}Step 1: Validating secret migration status...${NC}"

VALIDATION_FAILED=false
PLAIN_TEXT_COUNT=0
ENCRYPTED_COUNT=0
MISSING_ENCRYPTED=0

for secret_name in "${!PLAIN_TEXT_SECRETS[@]}"; do
    plain_path="${PLAIN_TEXT_SECRETS[$secret_name]}"
    encrypted_path="/run/agenix/$secret_name"
    
    echo -n "  Checking $secret_name... "
    
    if [ -f "$plain_path" ]; then
        PLAIN_TEXT_COUNT=$((PLAIN_TEXT_COUNT + 1))
        
        if [ -f "$encrypted_path" ]; then
            # Both exist - compare contents
            plain_content=$(cat "$plain_path" 2>/dev/null | tr -d '\n')
            encrypted_content=$(cat "$encrypted_path" 2>/dev/null | tr -d '\n')
            
            if [ "$plain_content" = "$encrypted_content" ]; then
                echo -e "${GREEN}✓${NC} Migrated (contents match)"
                ENCRYPTED_COUNT=$((ENCRYPTED_COUNT + 1))
            else
                echo -e "${RED}✗${NC} Contents differ between plain and encrypted!"
                log "ERROR: $secret_name has different contents in plain vs encrypted"
                VALIDATION_FAILED=true
            fi
        else
            echo -e "${YELLOW}⚠${NC} Plain text exists but no encrypted version"
            log "WARNING: $secret_name exists in plain text but not encrypted"
            MISSING_ENCRYPTED=$((MISSING_ENCRYPTED + 1))
        fi
    else
        if [ -f "$encrypted_path" ]; then
            echo -e "${GREEN}✓${NC} Already cleaned (only encrypted exists)"
            ENCRYPTED_COUNT=$((ENCRYPTED_COUNT + 1))
        else
            echo -e "${BLUE}-${NC} Not found (neither plain nor encrypted)"
        fi
    fi
done

echo
echo "Summary:"
echo "  Plain text secrets found: $PLAIN_TEXT_COUNT"
echo "  Encrypted secrets found: $ENCRYPTED_COUNT"
echo "  Missing encrypted versions: $MISSING_ENCRYPTED"

if [ "$VALIDATION_FAILED" = "true" ]; then
    echo
    echo -e "${RED}ERROR: Validation failed. Some secrets have mismatched contents.${NC}"
    echo "Please re-run the migration process before cleaning up."
    exit 1
fi

if [ $MISSING_ENCRYPTED -gt 0 ]; then
    echo
    echo -e "${YELLOW}WARNING: $MISSING_ENCRYPTED secrets exist in plain text but have no encrypted version.${NC}"
    echo "These secrets should be migrated first using:"
    echo "  sudo /path/to/migrate-secret.sh <secret-name>"
    
    if [ "$DRY_RUN" != "true" ]; then
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborting."
            exit 1
        fi
    fi
fi

if [ $PLAIN_TEXT_COUNT -eq 0 ]; then
    echo
    echo -e "${GREEN}No plain text secrets found. System is already clean!${NC}"
    exit 0
fi

# Step 2: Create backup of plain text secrets
echo
echo -e "${BLUE}Step 2: Creating backup of plain text secrets...${NC}"

if [ "$DRY_RUN" != "true" ]; then
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    log "Created backup directory: $BACKUP_DIR"
fi

for secret_name in "${!PLAIN_TEXT_SECRETS[@]}"; do
    plain_path="${PLAIN_TEXT_SECRETS[$secret_name]}"
    
    if [ -f "$plain_path" ]; then
        backup_path="$BACKUP_DIR/$(basename "$plain_path")"
        echo -n "  Backing up $secret_name... "
        
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${BLUE}[DRY-RUN]${NC} Would backup to $backup_path"
        else
            cp -p "$plain_path" "$backup_path"
            chmod 600 "$backup_path"
            echo -e "${GREEN}✓${NC} Backed up"
            log "Backed up $plain_path to $backup_path"
        fi
    fi
done

# Step 3: Update service configurations
echo
echo -e "${BLUE}Step 3: Checking service configurations...${NC}"

# Check if services are configured to use agenix paths
services_to_check=(
    "media-auto-config.service"
    "cistern-auth-setup.service"
)

for service in "${services_to_check[@]}"; do
    echo -n "  Checking $service... "
    
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        # Check if service references plain text paths
        if systemctl cat "$service" | grep -q '/var/lib/media/auto-config/.*\.txt\|/var/lib/cistern/auth/.*\.txt'; then
            echo -e "${YELLOW}⚠${NC} Still references plain text paths"
            log "WARNING: $service still references plain text secret paths"
        else
            echo -e "${GREEN}✓${NC} Using encrypted secrets"
        fi
    else
        echo -e "${BLUE}-${NC} Not enabled"
    fi
done

# Step 4: Remove plain text secrets
echo
echo -e "${BLUE}Step 4: Removing plain text secrets...${NC}"

REMOVED_COUNT=0

for secret_name in "${!PLAIN_TEXT_SECRETS[@]}"; do
    plain_path="${PLAIN_TEXT_SECRETS[$secret_name]}"
    
    if [ -f "$plain_path" ]; then
        echo -n "  Removing $secret_name... "
        
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${BLUE}[DRY-RUN]${NC} Would remove $plain_path"
        else
            # Secure deletion - overwrite before removing
            dd if=/dev/urandom of="$plain_path" bs=1024 count=1 >/dev/null 2>&1
            rm -f "$plain_path"
            echo -e "${GREEN}✓${NC} Removed"
            log "Securely removed $plain_path"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    fi
done

# Step 5: Clean up empty directories
echo
echo -e "${BLUE}Step 5: Cleaning up empty directories...${NC}"

dirs_to_check=(
    "/var/lib/media/auto-config"
    "/var/lib/cistern/auth"
    "/var/lib/cistern/authentik"
)

for dir in "${dirs_to_check[@]}"; do
    if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        echo -n "  Removing empty directory $dir... "
        
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${BLUE}[DRY-RUN]${NC} Would remove"
        else
            rmdir "$dir"
            echo -e "${GREEN}✓${NC} Removed"
            log "Removed empty directory $dir"
        fi
    fi
done

# Final summary
echo
echo -e "${BLUE}=== Cleanup Summary ===${NC}"

if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}DRY-RUN completed. No changes were made.${NC}"
    echo
    echo "Would have:"
    echo "  - Backed up $PLAIN_TEXT_COUNT plain text secrets to $BACKUP_DIR"
    echo "  - Removed $PLAIN_TEXT_COUNT plain text secret files"
    echo
    echo "To perform actual cleanup, run:"
    echo "  DRY_RUN=false $0"
else
    echo -e "${GREEN}Cleanup completed successfully!${NC}"
    echo
    echo "Results:"
    echo "  - Backed up $PLAIN_TEXT_COUNT secrets to: $BACKUP_DIR"
    echo "  - Removed $REMOVED_COUNT plain text secret files"
    echo "  - Log file: $LOG_FILE"
    echo
    echo -e "${YELLOW}IMPORTANT:${NC}"
    echo "  - Backup stored at: $BACKUP_DIR"
    echo "  - Keep this backup until you've verified all services work correctly"
    echo "  - After 30 days of successful operation, securely delete the backup:"
    echo "    sudo rm -rf $BACKUP_DIR"
fi

# Post-cleanup validation
if [ "$DRY_RUN" != "true" ] && [ $REMOVED_COUNT -gt 0 ]; then
    echo
    echo -e "${BLUE}Running post-cleanup validation...${NC}"
    
    # Check if any plain text secrets remain
    REMAINING=0
    for secret_name in "${!PLAIN_TEXT_SECRETS[@]}"; do
        plain_path="${PLAIN_TEXT_SECRETS[$secret_name]}"
        if [ -f "$plain_path" ]; then
            REMAINING=$((REMAINING + 1))
            echo -e "${RED}  ERROR: $plain_path still exists!${NC}"
        fi
    done
    
    if [ $REMAINING -eq 0 ]; then
        echo -e "${GREEN}  ✓ All plain text secrets successfully removed${NC}"
        log "Post-cleanup validation passed"
    else
        echo -e "${RED}  ERROR: $REMAINING plain text secrets still exist${NC}"
        log "ERROR: Post-cleanup validation failed - $REMAINING secrets remain"
    fi
fi

log "Cleanup script completed (DRY_RUN=$DRY_RUN)"