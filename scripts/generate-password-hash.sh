#!/usr/bin/env bash
# Script to generate bcrypt password hashes for Cistern authentication

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Cistern Password Hash Generator${NC}"
echo "================================"
echo

# Check if htpasswd is available
if ! command -v htpasswd &> /dev/null; then
    echo -e "${RED}Error: htpasswd not found!${NC}"
    echo "Please install Apache httpd tools:"
    echo "  - On NixOS: nix-shell -p apacheHttpd"
    echo "  - On macOS: brew install httpd"
    echo "  - On Ubuntu/Debian: apt install apache2-utils"
    exit 1
fi

# Parse command line arguments
USERNAME="${1:-}"
PASSWORD="${2:-}"

# If no arguments provided, prompt for input
if [ -z "$USERNAME" ]; then
    read -p "Enter username: " USERNAME
fi

if [ -z "$PASSWORD" ]; then
    # Prompt for password securely
    read -s -p "Enter password: " PASSWORD
    echo
    read -s -p "Confirm password: " PASSWORD_CONFIRM
    echo
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo -e "${RED}Error: Passwords do not match!${NC}"
        exit 1
    fi
fi

# Validate input
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Username and password are required!${NC}"
    exit 1
fi

# Generate bcrypt hash with cost factor 10
echo -e "\n${YELLOW}Generating bcrypt hash...${NC}"
HASH=$(htpasswd -nbBC 10 "$USERNAME" "$PASSWORD" | cut -d: -f2)

# Display results
echo -e "\n${GREEN}Successfully generated password hash!${NC}"
echo "====================================="
echo -e "Username: ${YELLOW}$USERNAME${NC}"
echo -e "Hash: ${YELLOW}$HASH${NC}"
echo
echo "To use this in your Cistern configuration:"
echo
echo "1. In terraform variables:"
echo "   admin_password_hash = \"$HASH\""
echo
echo "2. In NixOS configuration (cistern.auth.users):"
echo "   \"$USERNAME\" = \"$HASH\";"
echo
echo -e "${YELLOW}Note: Store this hash securely and never commit passwords to git!${NC}"