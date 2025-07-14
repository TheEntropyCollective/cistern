#!/usr/bin/env bash
#
# Migrate authentication secrets from plain text to agenix encryption
# This script handles migration of admin passwords and authentik secrets

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_info() { echo "[INFO] $1"; }

# Check if age is installed
if ! command -v age &> /dev/null; then
    print_error "age is not installed. Please install it first."
    exit 1
fi

# Configuration
SECRETS_DIR="${SECRETS_DIR:-/Users/jconnuck/cistern/secrets}"
AGE_KEY_FILE="${AGE_KEY_FILE:-/etc/cistern/age.key}"
SECRETS_NIX_FILE="$SECRETS_DIR/secrets.nix"

# Check if secrets directory exists
if [ ! -d "$SECRETS_DIR" ]; then
    print_error "Secrets directory not found: $SECRETS_DIR"
    exit 1
fi

# Check if age key exists
if [ ! -f "$AGE_KEY_FILE" ]; then
    print_warning "Age key not found at $AGE_KEY_FILE"
    print_info "Generating new age key..."
    mkdir -p "$(dirname "$AGE_KEY_FILE")"
    age-keygen -o "$AGE_KEY_FILE"
    chmod 600 "$AGE_KEY_FILE"
    print_success "Generated age key at $AGE_KEY_FILE"
fi

# Get age public key
AGE_PUBLIC_KEY=$(age-keygen -y "$AGE_KEY_FILE")
print_info "Using age public key: $AGE_PUBLIC_KEY"

# Function to encrypt a secret
encrypt_secret() {
    local secret_name=$1
    local plain_text_path=$2
    local encrypted_path="$SECRETS_DIR/${secret_name}.age"
    
    if [ -f "$plain_text_path" ]; then
        print_info "Migrating $secret_name from $plain_text_path"
        
        # Encrypt the secret
        age -r "$AGE_PUBLIC_KEY" -o "$encrypted_path" < "$plain_text_path"
        chmod 600 "$encrypted_path"
        
        print_success "Encrypted $secret_name to $encrypted_path"
        return 0
    else
        print_warning "Plain text secret not found: $plain_text_path"
        return 1
    fi
}

# Function to generate and encrypt a new secret
generate_and_encrypt_secret() {
    local secret_name=$1
    local secret_type=$2
    local encrypted_path="$SECRETS_DIR/${secret_name}.age"
    
    print_info "Generating new $secret_name"
    
    case "$secret_type" in
        password)
            openssl rand -base64 16 | tr -d '\n' | age -r "$AGE_PUBLIC_KEY" -o "$encrypted_path"
            ;;
        db-password)
            openssl rand -base64 32 | tr -d '\n' | age -r "$AGE_PUBLIC_KEY" -o "$encrypted_path"
            ;;
        secret-key)
            openssl rand -base64 50 | tr -d '\n' | age -r "$AGE_PUBLIC_KEY" -o "$encrypted_path"
            ;;
        *)
            print_error "Unknown secret type: $secret_type"
            return 1
            ;;
    esac
    
    chmod 600 "$encrypted_path"
    print_success "Generated and encrypted $secret_name"
}

# Main migration logic
print_info "Starting authentication secrets migration..."

# Migrate admin password
if [ -f "/var/lib/cistern/auth/admin-password.txt" ]; then
    encrypt_secret "admin-password" "/var/lib/cistern/auth/admin-password.txt"
elif [ ! -f "$SECRETS_DIR/admin-password.age" ]; then
    generate_and_encrypt_secret "admin-password" "password"
fi

# Migrate authentik database password
if [ -f "/var/lib/cistern/authentik/db-password" ]; then
    encrypt_secret "authentik-db-password" "/var/lib/cistern/authentik/db-password"
elif [ ! -f "$SECRETS_DIR/authentik-db-password.age" ]; then
    generate_and_encrypt_secret "authentik-db-password" "db-password"
fi

# Migrate authentik admin password
if [ -f "/var/lib/cistern/authentik/admin-password" ]; then
    encrypt_secret "authentik-admin-password" "/var/lib/cistern/authentik/admin-password"
elif [ ! -f "$SECRETS_DIR/authentik-admin-password.age" ]; then
    generate_and_encrypt_secret "authentik-admin-password" "password"
fi

# Migrate authentik secret key
if [ -f "/var/lib/cistern/authentik/secret-key" ]; then
    encrypt_secret "authentik-secret-key" "/var/lib/cistern/authentik/secret-key"
elif [ ! -f "$SECRETS_DIR/authentik-secret-key.age" ]; then
    generate_and_encrypt_secret "authentik-secret-key" "secret-key"
fi

# Generate SMTP password if it doesn't exist (optional)
if [ ! -f "$SECRETS_DIR/authentik-smtp-password.age" ]; then
    print_info "Generating placeholder SMTP password (configure when enabling SMTP)"
    generate_and_encrypt_secret "authentik-smtp-password" "password"
fi

# Check migration status
print_info ""
print_info "Migration Status:"
print_info "================"

for secret in admin-password authentik-db-password authentik-admin-password authentik-secret-key authentik-smtp-password; do
    if [ -f "$SECRETS_DIR/${secret}.age" ]; then
        print_success "$secret: Encrypted ✓"
    else
        print_error "$secret: Missing ✗"
    fi
done

print_info ""
print_warning "Next steps:"
print_warning "1. Add your SSH public key to $SECRETS_NIX_FILE in the 'admins' section"
print_warning "2. Add host public keys to $SECRETS_NIX_FILE in the 'hosts' section"
print_warning "3. Commit the encrypted secrets to git (they're safe to commit)"
print_warning "4. Deploy the configuration to use encrypted secrets"
print_warning "5. After verifying everything works, remove plain text secrets"

print_info ""
print_info "To remove plain text secrets after verification:"
print_info "  sudo rm -f /var/lib/cistern/auth/admin-password.txt"
print_info "  sudo rm -f /var/lib/cistern/authentik/db-password"
print_info "  sudo rm -f /var/lib/cistern/authentik/admin-password"
print_info "  sudo rm -f /var/lib/cistern/authentik/secret-key"