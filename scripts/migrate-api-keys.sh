#!/usr/bin/env bash
#
# Cistern API Key Migration Script
# Migrates plain text API keys to agenix encrypted secrets
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Configuration
PLAIN_TEXT_DIR="/var/lib/media/auto-config"
SECRETS_DIR="../secrets"
AGE_PUBLIC_KEY_FILE="/etc/cistern/age.pub"

# API key mappings
declare -A API_KEYS=(
    ["sonarr-api-key"]="$PLAIN_TEXT_DIR/sonarr-api-key"
    ["radarr-api-key"]="$PLAIN_TEXT_DIR/radarr-api-key"
    ["prowlarr-api-key"]="$PLAIN_TEXT_DIR/prowlarr-api-key"
    ["bazarr-api-key"]="$PLAIN_TEXT_DIR/bazarr-api-key"
    ["jellyfin-api-key"]="$PLAIN_TEXT_DIR/jellyfin-api-key"
    ["sabnzbd-api-key"]="$PLAIN_TEXT_DIR/sabnzbd-api-key"
    ["transmission-rpc-password"]="$PLAIN_TEXT_DIR/transmission-rpc-password"
)

# Additional secrets that might exist
ADMIN_PASSWORD_PATH="/var/lib/cistern/auth/admin-password.txt"

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check for required tools
check_dependencies() {
    local deps=("age" "age-keygen")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Missing required tool: $dep"
            log_info "Please ensure you're in a nix shell or install the missing tools"
            exit 1
        fi
    done
}

# Generate age key if it doesn't exist
ensure_age_key() {
    local age_key_file="/etc/cistern/age.key"
    
    if [[ ! -f "$age_key_file" ]]; then
        log_info "Generating age key..."
        mkdir -p /etc/cistern
        age-keygen -o "$age_key_file"
        chmod 600 "$age_key_file"
        log_success "Age key generated at $age_key_file"
    else
        log_info "Age key already exists at $age_key_file"
    fi
    
    # Extract public key
    if [[ ! -f "$AGE_PUBLIC_KEY_FILE" ]]; then
        age-keygen -y "$age_key_file" > "$AGE_PUBLIC_KEY_FILE"
        chmod 644 "$AGE_PUBLIC_KEY_FILE"
        log_success "Public key extracted to $AGE_PUBLIC_KEY_FILE"
    fi
}

# Get age recipients from secrets.nix
get_age_recipients() {
    local recipients=""
    
    # Get the public key from the age key file
    if [[ -f "$AGE_PUBLIC_KEY_FILE" ]]; then
        recipients=$(cat "$AGE_PUBLIC_KEY_FILE")
    else
        log_error "No age public key found"
        exit 1
    fi
    
    echo "$recipients"
}

# Migrate a single API key
migrate_api_key() {
    local key_name=$1
    local plain_path=$2
    local secret_path="$SECRETS_DIR/${key_name}.age"
    
    # Check if plain text file exists
    if [[ ! -f "$plain_path" ]]; then
        log_warning "Plain text file not found: $plain_path"
        return 1
    fi
    
    # Check if already migrated
    if [[ -f "$secret_path" ]]; then
        log_info "$key_name already migrated to $secret_path"
        return 0
    fi
    
    # Get the recipients
    local recipients=$(get_age_recipients)
    if [[ -z "$recipients" ]]; then
        log_error "No age recipients found"
        return 1
    fi
    
    # Read the API key
    local api_key=$(cat "$plain_path" | tr -d '\n')
    if [[ -z "$api_key" ]]; then
        log_warning "Empty API key in $plain_path"
        return 1
    fi
    
    # Encrypt the API key
    log_info "Encrypting $key_name..."
    echo -n "$api_key" | age -r "$recipients" -o "$secret_path"
    
    if [[ $? -eq 0 ]]; then
        chmod 644 "$secret_path"
        log_success "Migrated $key_name to $secret_path"
        
        # Optionally backup the plain text file
        mv "$plain_path" "${plain_path}.backup"
        log_info "Backed up plain text to ${plain_path}.backup"
        
        return 0
    else
        log_error "Failed to encrypt $key_name"
        return 1
    fi
}

# Migrate admin password
migrate_admin_password() {
    if [[ -f "$ADMIN_PASSWORD_PATH" ]]; then
        log_info "Migrating admin password..."
        migrate_api_key "admin-password" "$ADMIN_PASSWORD_PATH"
    else
        log_info "No admin password found to migrate"
    fi
}

# Update secrets.nix with host public keys
update_secrets_nix() {
    local secrets_nix="$SECRETS_DIR/secrets.nix"
    local pub_key=$(cat "$AGE_PUBLIC_KEY_FILE")
    local hostname=$(hostname)
    
    log_info "Updating secrets.nix with host public key..."
    
    # This is a simple placeholder - in production, you'd want to properly
    # parse and update the Nix file
    log_warning "Please manually add the following to your secrets.nix hosts section:"
    echo "    $hostname = \"$pub_key\";"
}

# Main migration process
main() {
    log_info "Starting Cistern API key migration..."
    
    # Check prerequisites
    check_permissions
    check_dependencies
    
    # Ensure age key exists
    ensure_age_key
    
    # Create secrets directory if it doesn't exist
    mkdir -p "$SECRETS_DIR"
    
    # Migrate API keys
    local success_count=0
    local total_count=0
    
    for key_name in "${!API_KEYS[@]}"; do
        ((total_count++))
        if migrate_api_key "$key_name" "${API_KEYS[$key_name]}"; then
            ((success_count++))
        fi
    done
    
    # Migrate admin password
    migrate_admin_password
    
    # Update secrets.nix
    update_secrets_nix
    
    # Summary
    echo
    log_info "Migration Summary:"
    log_info "  Total API keys processed: $total_count"
    log_info "  Successfully migrated: $success_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "All API keys migrated successfully!"
        log_info "Next steps:"
        log_info "  1. Update secrets.nix with the host public key (shown above)"
        log_info "  2. Commit the encrypted secrets to git"
        log_info "  3. Deploy the updated configuration"
        log_info "  4. Remove backup files after verifying everything works"
    else
        log_warning "Some API keys could not be migrated"
        log_info "Please check the logs and migrate manually if needed"
    fi
}

# Run main function
main "$@"