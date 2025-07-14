#!/usr/bin/env bash
# Generate age keys for Cistern secrets management

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_ROOT/secrets"

echo -e "${GREEN}Cistern Age Key Generation${NC}"
echo "=============================="
echo

# Function to generate age key from SSH key
ssh_to_age_key() {
    local ssh_key="$1"
    if command -v ssh-to-age >/dev/null 2>&1; then
        echo "$ssh_key" | ssh-to-age 2>/dev/null || echo ""
    else
        echo -e "${RED}Error: ssh-to-age not found. Run 'nix develop' first.${NC}" >&2
        return 1
    fi
}

# Function to extract SSH host key
get_host_ssh_key() {
    local host="$1"
    local port="${2:-22}"
    
    echo -e "${YELLOW}Fetching SSH key for $host:$port...${NC}"
    ssh-keyscan -p "$port" -t ed25519 "$host" 2>/dev/null | grep -v "^#" | head -1
}

# Main menu
case "${1:-}" in
    admin)
        echo "Generating admin age key..."
        echo
        
        KEY_FILE="${2:-$HOME/.config/cistern/age.key}"
        mkdir -p "$(dirname "$KEY_FILE")"
        
        if [ -f "$KEY_FILE" ]; then
            echo -e "${YELLOW}Warning: Age key already exists at $KEY_FILE${NC}"
            read -p "Overwrite? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 0
            fi
        fi
        
        age-keygen -o "$KEY_FILE" 2>/dev/null
        chmod 600 "$KEY_FILE"
        
        echo -e "${GREEN}Admin age key generated at: $KEY_FILE${NC}"
        echo
        echo "Add the following public key to secrets/secrets.nix:"
        grep "public key:" "$KEY_FILE" | cut -d' ' -f4
        ;;
        
    host)
        if [ $# -lt 2 ]; then
            echo "Usage: $0 host <hostname/ip> [port]"
            exit 1
        fi
        
        HOST="$2"
        PORT="${3:-22}"
        
        # Get SSH host key
        SSH_KEY=$(get_host_ssh_key "$HOST" "$PORT")
        if [ -z "$SSH_KEY" ]; then
            echo -e "${RED}Error: Could not fetch SSH key from $HOST:$PORT${NC}"
            exit 1
        fi
        
        # Convert to age key
        AGE_KEY=$(echo "$SSH_KEY" | ssh-to-age)
        if [ -z "$AGE_KEY" ]; then
            echo -e "${RED}Error: Could not convert SSH key to age key${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}Successfully generated age key for $HOST${NC}"
        echo
        echo "Add the following to secrets/secrets.nix under 'hosts':"
        echo "  $HOST = \"$AGE_KEY\";"
        ;;
        
    convert-ssh)
        echo "Converting SSH public key to age key..."
        echo "Paste your SSH public key and press Enter:"
        read -r SSH_KEY
        
        AGE_KEY=$(ssh_to_age_key "$SSH_KEY")
        if [ -z "$AGE_KEY" ]; then
            echo -e "${RED}Error: Invalid SSH key or conversion failed${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}Age public key:${NC}"
        echo "$AGE_KEY"
        ;;
        
    list)
        echo "Current age keys in secrets.nix:"
        echo
        
        if [ -f "$SECRETS_DIR/secrets.nix" ]; then
            echo -e "${YELLOW}Admins:${NC}"
            grep -A20 "admins = \[" "$SECRETS_DIR/secrets.nix" | grep "ssh-" || echo "  (none configured)"
            
            echo
            echo -e "${YELLOW}Hosts:${NC}"
            grep -A20 "hosts = {" "$SECRETS_DIR/secrets.nix" | grep "=" | grep -v "hosts = {" || echo "  (none configured)"
        else
            echo -e "${RED}Error: secrets/secrets.nix not found${NC}"
            exit 1
        fi
        ;;
        
    *)
        echo "Usage: $0 <command> [options]"
        echo
        echo "Commands:"
        echo "  admin [key-file]     Generate admin age key (default: ~/.config/cistern/age.key)"
        echo "  host <host> [port]   Generate age key from host SSH key"
        echo "  convert-ssh          Convert SSH public key to age key"
        echo "  list                 List configured age keys"
        echo
        echo "Examples:"
        echo "  $0 admin"
        echo "  $0 host 192.168.1.50"
        echo "  $0 host eden.local 22"
        echo "  $0 convert-ssh"
        exit 1
        ;;
esac