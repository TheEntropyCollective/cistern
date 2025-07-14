#!/usr/bin/env bash
#
# Cistern Complete Secrets Migration Script
# Migrates all plain text secrets to agenix encrypted secrets
#
set -euo pipefail

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}==> $1${NC}"
}

# Configuration
BACKUP_DIR="/root/cistern-secrets-backup"
SECRETS_DIR="${SCRIPT_DIR}/../secrets"
AGE_KEY_FILE="/etc/cistern/age.key"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Migration status tracking
TOTAL_SECRETS=0
MIGRATED_SECRETS=0
FAILED_SECRETS=0
BACKED_UP_SECRETS=0

# Parse command line arguments
BACKUP_ONLY=false
SKIP_BACKUP=false
FORCE_MIGRATE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-only)
            BACKUP_ONLY=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --force)
            FORCE_MIGRATE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --backup-only    Only create backups, don't migrate"
            echo "  --skip-backup    Skip backup creation (dangerous!)"
            echo "  --force          Force migration even if secrets exist"
            echo "  --dry-run        Show what would be done without making changes"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if running as root
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check for required tools
check_dependencies() {
    local deps=("age" "age-keygen" "openssl")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Missing required tool: $dep"
            log_info "Please ensure you're in a nix shell or install the missing tools"
            exit 1
        fi
    done
}

# Define all secrets with their plain text locations
declare -A ALL_SECRETS=(
    # API Keys
    ["sonarr-api-key"]="/var/lib/media/auto-config/sonarr-api-key.txt"
    ["radarr-api-key"]="/var/lib/media/auto-config/radarr-api-key.txt"
    ["prowlarr-api-key"]="/var/lib/media/auto-config/prowlarr-api-key.txt"
    ["bazarr-api-key"]="/var/lib/media/auto-config/bazarr-api-key.txt"
    ["jellyfin-api-key"]="/var/lib/media/auto-config/jellyfin-api-key.txt"
    ["sabnzbd-api-key"]="/var/lib/media/auto-config/sabnzbd-api-key.txt"
    ["transmission-rpc-password"]="/var/lib/media/auto-config/transmission-rpc-password.txt"
    
    # Authentication Secrets
    ["admin-password"]="/var/lib/cistern/auth/admin-password.txt"
    ["authentik-db-password"]="/var/lib/cistern/authentik/db-password"
    ["authentik-admin-password"]="/var/lib/cistern/authentik/admin-password"
    ["authentik-smtp-password"]="/var/lib/cistern/authentik/smtp-password"
    ["authentik-secret-key"]="/var/lib/cistern/authentik/secret-key"
)

# Create comprehensive backup
create_backup() {
    log_step "Creating backup of all plain text secrets"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup directory: $BACKUP_DIR/$TIMESTAMP"
        return 0
    fi
    
    # Create timestamped backup directory
    local backup_path="$BACKUP_DIR/$TIMESTAMP"
    mkdir -p "$backup_path"
    chmod 700 "$backup_path"
    
    # Backup each secret
    for secret_name in "${!ALL_SECRETS[@]}"; do
        local plain_path="${ALL_SECRETS[$secret_name]}"
        
        if [[ -f "$plain_path" ]]; then
            local backup_file="$backup_path/${secret_name}.txt"
            local backup_dir=$(dirname "$backup_file")
            
            mkdir -p "$backup_dir"
            cp -p "$plain_path" "$backup_file"
            chmod 600 "$backup_file"
            
            log_success "Backed up: $secret_name"
            ((BACKED_UP_SECRETS++))
        else
            log_info "No plain text found for: $secret_name (might already be migrated)"
        fi
    done
    
    # Create backup manifest
    cat > "$backup_path/manifest.txt" << EOF
Cistern Secrets Backup
Created: $(date)
Total Secrets: ${#ALL_SECRETS[@]}
Backed Up: $BACKED_UP_SECRETS
Host: $(hostname)
EOF
    
    # Create restore script
    cat > "$backup_path/restore.sh" << 'EOF'
#!/bin/bash
# Restore script for Cistern secrets backup
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

echo "This will restore all plain text secrets from this backup."
read -p "Are you sure? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Restore each file
for file in $(find . -name "*.txt" -not -name "manifest.txt"); do
    dest_path="${file#./}"
    dest_path="/${dest_path%.txt}"
    
    echo "Restoring: $dest_path"
    mkdir -p "$(dirname "$dest_path")"
    cp -p "$file" "$dest_path"
done

echo "Restore complete!"
EOF
    chmod 700 "$backup_path/restore.sh"
    
    log_success "Backup created at: $backup_path"
    log_info "Total secrets backed up: $BACKED_UP_SECRETS"
}

# Generate status report
generate_status_report() {
    log_step "Generating migration status report"
    
    local plain_count=0
    local encrypted_count=0
    local missing_count=0
    
    echo ""
    echo "=== Cistern Secrets Migration Status Report ==="
    echo "Generated: $(date)"
    echo ""
    echo "Secret Status:"
    echo "-------------------------------------------------"
    
    for secret_name in "${!ALL_SECRETS[@]}"; do
        local plain_path="${ALL_SECRETS[$secret_name]}"
        local encrypted_path="$SECRETS_DIR/${secret_name}.age"
        local runtime_path="/run/agenix/$secret_name"
        
        printf "%-30s: " "$secret_name"
        
        if [[ -f "$runtime_path" ]]; then
            echo -e "${GREEN}ENCRYPTED (Active)${NC}"
            ((encrypted_count++))
        elif [[ -f "$encrypted_path" ]]; then
            echo -e "${YELLOW}ENCRYPTED (Not deployed)${NC}"
            ((encrypted_count++))
        elif [[ -f "$plain_path" ]]; then
            echo -e "${RED}PLAIN TEXT${NC}"
            ((plain_count++))
        else
            echo -e "${RED}MISSING${NC}"
            ((missing_count++))
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "-------------------------------------------------"
    echo "Total Secrets:     ${#ALL_SECRETS[@]}"
    echo "Plain Text:        $plain_count"
    echo "Encrypted:         $encrypted_count"
    echo "Missing:           $missing_count"
    echo ""
    
    if [[ $plain_count -eq 0 && $missing_count -eq 0 ]]; then
        log_success "All secrets are encrypted!"
    elif [[ $plain_count -gt 0 ]]; then
        log_warning "$plain_count secrets still need migration"
    fi
    
    if [[ $missing_count -gt 0 ]]; then
        log_warning "$missing_count secrets are missing and may need to be generated"
    fi
}

# Run individual migration scripts
run_migrations() {
    log_step "Running individual migration scripts"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run migration scripts"
        return 0
    fi
    
    # Run API key migration
    if [[ -x "$SCRIPT_DIR/migrate-api-keys.sh" ]]; then
        log_info "Running API key migration..."
        if "$SCRIPT_DIR/migrate-api-keys.sh"; then
            log_success "API key migration completed"
        else
            log_error "API key migration failed"
            ((FAILED_SECRETS++))
        fi
    else
        log_warning "API key migration script not found or not executable"
    fi
    
    # Run authentication secrets migration
    if [[ -x "$SCRIPT_DIR/migrate-auth-secrets.sh" ]]; then
        log_info "Running authentication secrets migration..."
        if "$SCRIPT_DIR/migrate-auth-secrets.sh"; then
            log_success "Authentication secrets migration completed"
        else
            log_error "Authentication secrets migration failed"
            ((FAILED_SECRETS++))
        fi
    else
        log_warning "Authentication secrets migration script not found or not executable"
    fi
}

# Validate migration results
validate_migration() {
    log_step "Validating migration results"
    
    if [[ -x "$SCRIPT_DIR/validate-secrets.sh" ]]; then
        "$SCRIPT_DIR/validate-secrets.sh"
    else
        log_warning "Validation script not found, performing basic checks..."
        
        # Basic validation
        local valid_count=0
        
        for secret_name in "${!ALL_SECRETS[@]}"; do
            local encrypted_path="$SECRETS_DIR/${secret_name}.age"
            
            if [[ -f "$encrypted_path" ]]; then
                # Try to decrypt to validate
                if age -d -i "$AGE_KEY_FILE" "$encrypted_path" > /dev/null 2>&1; then
                    ((valid_count++))
                else
                    log_error "Failed to decrypt: $secret_name"
                fi
            fi
        done
        
        log_info "Successfully validated $valid_count encrypted secrets"
    fi
}

# Main migration process
main() {
    log_info "Starting Cistern complete secrets migration"
    log_info "Timestamp: $TIMESTAMP"
    
    # Check prerequisites
    check_permissions
    check_dependencies
    
    # Show current status
    generate_status_report
    
    # Create backup unless skipped
    if [[ "$SKIP_BACKUP" != "true" ]]; then
        create_backup
        
        if [[ "$BACKUP_ONLY" == "true" ]]; then
            log_success "Backup complete. Exiting without migration."
            exit 0
        fi
    else
        log_warning "Skipping backup creation (--skip-backup specified)"
    fi
    
    # Ensure age key exists
    if [[ ! -f "$AGE_KEY_FILE" ]]; then
        log_step "Generating age key"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            "$SCRIPT_DIR/generate-age-keys.sh"
        else
            log_info "[DRY RUN] Would generate age keys"
        fi
    fi
    
    # Run migrations
    run_migrations
    
    # Validate results
    validate_migration
    
    # Final status report
    echo ""
    log_step "Migration Complete"
    generate_status_report
    
    # Provide next steps
    echo ""
    log_info "Next steps:"
    log_info "1. Review the migration status above"
    log_info "2. Update secrets/secrets.nix with admin and host keys"
    log_info "3. Commit encrypted secrets to git"
    log_info "4. Deploy the updated configuration"
    log_info "5. Verify all services are working correctly"
    log_info "6. Remove plain text secrets after verification"
    
    if [[ $FAILED_SECRETS -gt 0 ]]; then
        log_warning "Some secrets failed to migrate. Please check the logs."
        exit 1
    fi
    
    log_success "Migration completed successfully!"
}

# Run main function
main "$@"