#!/usr/bin/env bash
#
# Cistern Secrets Validation Script
# Validates that all required secrets exist and can be decrypted
#
set -euo pipefail

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

log_section() {
    echo -e "\n${CYAN}==> $1${NC}"
}

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SECRETS_DIR="${SCRIPT_DIR}/../secrets"
AGE_KEY_FILE="/etc/cistern/age.key"
RUNTIME_DIR="/run/agenix"

# Validation results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Parse command line arguments
FULL_CHECK=false
QUIET=false
SERVICE_CHECK=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            FULL_CHECK=true
            shift
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --no-service-check)
            SERVICE_CHECK=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full               Perform comprehensive validation"
            echo "  --quiet, -q          Only show errors and summary"
            echo "  --no-service-check   Skip service accessibility checks"
            echo "  --help               Show this help message"
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
        log_warning "Not running as root. Some checks may be limited."
    fi
}

# Define all required secrets
declare -A REQUIRED_SECRETS=(
    # API Keys
    ["sonarr-api-key"]="string:32"
    ["radarr-api-key"]="string:32"
    ["prowlarr-api-key"]="string:32"
    ["bazarr-api-key"]="string:32"
    ["jellyfin-api-key"]="string:32"
    ["sabnzbd-api-key"]="string:32"
    ["transmission-rpc-password"]="password:16"
    
    # Authentication Secrets
    ["admin-password"]="password:16"
    ["authentik-db-password"]="password:32"
    ["authentik-admin-password"]="password:16"
    ["authentik-smtp-password"]="password:16"
    ["authentik-secret-key"]="string:50"
)

# Check if a secret exists and can be decrypted
check_secret() {
    local secret_name=$1
    local secret_type=$2
    local encrypted_path="$SECRETS_DIR/${secret_name}.age"
    local runtime_path="$RUNTIME_DIR/$secret_name"
    
    ((TOTAL_CHECKS++))
    
    if [[ "$QUIET" != "true" ]]; then
        printf "Checking %-30s ... " "$secret_name"
    fi
    
    # Check if encrypted file exists
    if [[ ! -f "$encrypted_path" ]]; then
        log_error "Encrypted file missing: $encrypted_path"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    # Check if age key exists
    if [[ ! -f "$AGE_KEY_FILE" ]]; then
        log_error "Age key missing: $AGE_KEY_FILE"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    # Try to decrypt the secret
    local decrypted_content
    if decrypted_content=$(age -d -i "$AGE_KEY_FILE" "$encrypted_path" 2>&1); then
        # Validate content based on type
        local type_name="${secret_type%:*}"
        local min_length="${secret_type#*:}"
        
        if [[ ${#decrypted_content} -lt $min_length ]]; then
            log_warning "Content too short (expected at least $min_length chars)"
            ((WARNINGS++))
        fi
        
        # Check runtime availability
        if [[ -f "$runtime_path" ]]; then
            if [[ "$QUIET" != "true" ]]; then
                log_success "OK (deployed)"
            fi
        else
            if [[ "$QUIET" != "true" ]]; then
                echo -e "${YELLOW}OK (not deployed)${NC}"
            fi
            ((WARNINGS++))
        fi
        
        ((PASSED_CHECKS++))
        return 0
    else
        log_error "Decryption failed: $decrypted_content"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# Check age configuration
check_age_configuration() {
    log_section "Checking age configuration"
    
    ((TOTAL_CHECKS++))
    
    # Check age key file
    if [[ -f "$AGE_KEY_FILE" ]]; then
        local perms=$(stat -c %a "$AGE_KEY_FILE" 2>/dev/null || stat -f %p "$AGE_KEY_FILE" | cut -c 4-6)
        if [[ "$perms" == "600" ]]; then
            log_success "Age key file has correct permissions (600)"
            ((PASSED_CHECKS++))
        else
            log_warning "Age key file has insecure permissions: $perms (should be 600)"
            ((WARNINGS++))
            ((PASSED_CHECKS++))
        fi
        
        # Extract and display public key
        if command -v age-keygen &> /dev/null; then
            local pub_key=$(age-keygen -y "$AGE_KEY_FILE" 2>/dev/null)
            if [[ -n "$pub_key" ]]; then
                log_info "Age public key: $pub_key"
            fi
        fi
    else
        log_error "Age key file missing: $AGE_KEY_FILE"
        ((FAILED_CHECKS++))
    fi
    
    # Check runtime directory
    ((TOTAL_CHECKS++))
    if [[ -d "$RUNTIME_DIR" ]]; then
        log_success "Agenix runtime directory exists"
        ((PASSED_CHECKS++))
    else
        log_warning "Agenix runtime directory missing: $RUNTIME_DIR"
        log_info "This is normal if agenix hasn't been deployed yet"
        ((WARNINGS++))
        ((PASSED_CHECKS++))
    fi
}

# Check secrets.nix configuration
check_secrets_nix() {
    log_section "Checking secrets.nix configuration"
    
    local secrets_nix="$SECRETS_DIR/secrets.nix"
    
    ((TOTAL_CHECKS++))
    if [[ -f "$secrets_nix" ]]; then
        log_success "secrets.nix exists"
        ((PASSED_CHECKS++))
        
        # Check for admin keys
        if grep -q "admins = \[" "$secrets_nix"; then
            local admin_count=$(grep -A10 "admins = \[" "$secrets_nix" | grep -c "ssh-" || true)
            if [[ $admin_count -gt 0 ]]; then
                log_success "Found $admin_count admin SSH key(s)"
            else
                log_warning "No admin SSH keys configured"
                log_info "Add your SSH public key to decrypt secrets"
                ((WARNINGS++))
            fi
        fi
        
        # Check for host keys
        if grep -q "hosts = {" "$secrets_nix"; then
            local host_count=$(grep -A20 "hosts = {" "$secrets_nix" | grep -c "age1" || true)
            if [[ $host_count -gt 0 ]]; then
                log_success "Found $host_count host key(s)"
            else
                log_warning "No host keys configured"
                log_info "Run generate-age-keys.sh on each host and add the public keys"
                ((WARNINGS++))
            fi
        fi
    else
        log_error "secrets.nix missing"
        ((FAILED_CHECKS++))
    fi
}

# Check for plain text secrets
check_plain_text_secrets() {
    log_section "Checking for plain text secrets"
    
    local plain_dirs=(
        "/var/lib/media/auto-config"
        "/var/lib/cistern/auth"
        "/var/lib/cistern/authentik"
    )
    
    local found_plain=0
    
    for dir in "${plain_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r -d '' file; do
                log_warning "Found plain text secret: $file"
                ((found_plain++))
            done < <(find "$dir" -type f \( -name "*.txt" -o -name "*password*" -o -name "*key*" -o -name "*secret*" \) -print0 2>/dev/null || true)
        fi
    done
    
    ((TOTAL_CHECKS++))
    if [[ $found_plain -eq 0 ]]; then
        log_success "No plain text secrets found"
        ((PASSED_CHECKS++))
    else
        log_warning "Found $found_plain plain text secret(s)"
        log_info "Run migrate-all-secrets.sh to encrypt them"
        ((WARNINGS++))
        ((PASSED_CHECKS++))
    fi
}

# Check service accessibility (optional)
check_service_access() {
    if [[ "$SERVICE_CHECK" != "true" ]]; then
        return 0
    fi
    
    log_section "Checking service secret accessibility"
    
    # Map of services to their secret files
    declare -A SERVICE_SECRETS=(
        ["sonarr"]="/run/agenix/sonarr-api-key"
        ["radarr"]="/run/agenix/radarr-api-key"
        ["prowlarr"]="/run/agenix/prowlarr-api-key"
        ["bazarr"]="/run/agenix/bazarr-api-key"
        ["jellyfin"]="/run/agenix/jellyfin-api-key"
        ["sabnzbd"]="/run/agenix/sabnzbd-api-key"
    )
    
    for service in "${!SERVICE_SECRETS[@]}"; do
        local secret_path="${SERVICE_SECRETS[$service]}"
        
        ((TOTAL_CHECKS++))
        
        if systemctl is-active "$service" &>/dev/null; then
            if [[ -r "$secret_path" ]]; then
                log_success "$service can access its secret"
                ((PASSED_CHECKS++))
            else
                log_warning "$service service is running but secret not accessible"
                ((WARNINGS++))
                ((PASSED_CHECKS++))
            fi
        else
            if [[ "$QUIET" != "true" ]]; then
                log_info "$service service not running (skipping check)"
            fi
            ((PASSED_CHECKS++))
        fi
    done
}

# Perform comprehensive validation if requested
comprehensive_validation() {
    if [[ "$FULL_CHECK" != "true" ]]; then
        return 0
    fi
    
    log_section "Performing comprehensive validation"
    
    # Test actual decryption with content validation
    for secret_name in "${!REQUIRED_SECRETS[@]}"; do
        local encrypted_path="$SECRETS_DIR/${secret_name}.age"
        
        if [[ -f "$encrypted_path" ]]; then
            # Decrypt and validate content format
            if content=$(age -d -i "$AGE_KEY_FILE" "$encrypted_path" 2>/dev/null); then
                case "${REQUIRED_SECRETS[$secret_name]}" in
                    string:*)
                        if [[ "$content" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                            log_success "$secret_name: Valid string format"
                        else
                            log_warning "$secret_name: Unexpected characters in string"
                        fi
                        ;;
                    password:*)
                        if [[ ${#content} -ge 8 ]]; then
                            log_success "$secret_name: Password meets minimum length"
                        else
                            log_warning "$secret_name: Password too short"
                        fi
                        ;;
                esac
            fi
        fi
    done
    
    # Check for orphaned encrypted files
    log_info "Checking for orphaned encrypted files..."
    
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file" .age)
        if [[ ! ${REQUIRED_SECRETS[$basename]+x} ]]; then
            log_warning "Orphaned encrypted file: $file"
            ((WARNINGS++))
        fi
    done < <(find "$SECRETS_DIR" -name "*.age" -print0 2>/dev/null || true)
}

# Generate summary report
generate_summary() {
    echo ""
    echo "========================================="
    echo "     Cistern Secrets Validation Report   "
    echo "========================================="
    echo ""
    echo "Total Checks:    $TOTAL_CHECKS"
    echo "Passed:          $PASSED_CHECKS"
    echo "Failed:          $FAILED_CHECKS"
    echo "Warnings:        $WARNINGS"
    echo ""
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        if [[ $WARNINGS -eq 0 ]]; then
            log_success "All validation checks passed!"
        else
            log_success "Validation passed with $WARNINGS warning(s)"
        fi
    else
        log_error "Validation failed with $FAILED_CHECKS error(s)"
    fi
    
    # Provide recommendations
    if [[ $FAILED_CHECKS -gt 0 || $WARNINGS -gt 0 ]]; then
        echo ""
        echo "Recommendations:"
        
        if [[ ! -f "$AGE_KEY_FILE" ]]; then
            echo "  • Run generate-age-keys.sh to create age keys"
        fi
        
        if [[ $WARNINGS -gt 0 ]]; then
            echo "  • Review and address warnings above"
        fi
        
        echo "  • Run migrate-all-secrets.sh to migrate plain text secrets"
        echo "  • Update secrets.nix with proper admin and host keys"
        echo "  • Deploy the configuration to activate encrypted secrets"
    fi
}

# Main validation process
main() {
    if [[ "$QUIET" != "true" ]]; then
        log_info "Starting Cistern secrets validation"
        log_info "Mode: $([ "$FULL_CHECK" == "true" ] && echo "Full" || echo "Basic")"
    fi
    
    check_permissions
    
    # Basic checks
    check_age_configuration
    check_secrets_nix
    
    # Check each required secret
    log_section "Validating required secrets"
    for secret_name in "${!REQUIRED_SECRETS[@]}"; do
        check_secret "$secret_name" "${REQUIRED_SECRETS[$secret_name]}"
    done
    
    # Additional checks
    check_plain_text_secrets
    check_service_access
    
    # Comprehensive validation if requested
    comprehensive_validation
    
    # Generate summary
    generate_summary
    
    # Exit with appropriate code
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        exit 0  # Warnings don't fail the validation
    else
        exit 0
    fi
}

# Run main function
main "$@"