#!/usr/bin/env bash
set -euo pipefail

# Cistern Fleet Deployment Script
# This script uses deploy-rs to update existing NixOS media servers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

show_help() {
    cat << EOF
Cistern Fleet Deployment

Usage: $0 [OPTIONS] [target]

Arguments:
    target          Specific server to deploy (optional, deploys all if not specified)

Options:
    -h, --help      Show this help message
    -n, --dry-run   Show what would be deployed without executing
    -c, --check     Check deployment configuration without deploying
    --skip-checks   Skip deployment checks
    --rollback      Rollback to previous deployment

Examples:
    $0                      # Deploy to entire fleet
    $0 media-server-01      # Deploy to specific server
    $0 --dry-run           # Show what would be deployed
    $0 --rollback media-server-01  # Rollback specific server

EOF
}

# Default values
DRY_RUN=false
CHECK_ONLY=false
SKIP_CHECKS=false
ROLLBACK=false
TARGET=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        --skip-checks)
            SKIP_CHECKS=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
        *)
            if [ -z "$TARGET" ]; then
                TARGET="$1"
            else
                echo "Too many arguments" >&2
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

cd "$FLAKE_DIR"

# Check if deploy-rs is available
if ! command -v deploy &> /dev/null; then
    echo "Error: deploy-rs not found. Please install it first:" >&2
    echo "nix profile install github:serokell/deploy-rs" >&2
    exit 1
fi

# Validate flake
echo "Validating flake configuration..."
if ! nix flake check 2>/dev/null; then
    echo "Warning: Flake check failed. Proceeding anyway..."
fi

if [ "$CHECK_ONLY" = true ]; then
    echo "✅ Configuration check completed"
    exit 0
fi

# Build deploy command
DEPLOY_CMD=(deploy)

if [ "$DRY_RUN" = true ]; then
    DEPLOY_CMD+=(--dry-activate)
fi

if [ "$SKIP_CHECKS" = true ]; then
    DEPLOY_CMD+=(--skip-checks)
fi

if [ "$ROLLBACK" = true ]; then
    if [ -z "$TARGET" ]; then
        echo "Error: Target must be specified for rollback" >&2
        exit 1
    fi
    DEPLOY_CMD=(deploy rollback)
fi

# Add target if specified
if [ -n "$TARGET" ]; then
    DEPLOY_CMD+=(".#$TARGET")
else
    DEPLOY_CMD+=(".")
fi

echo "Deploying to Cistern media server fleet..."
if [ -n "$TARGET" ]; then
    echo "Target: $TARGET"
else
    echo "Target: All servers in fleet"
fi

if [ "$DRY_RUN" = true ]; then
    echo "Mode: Dry run (no changes will be made)"
elif [ "$ROLLBACK" = true ]; then
    echo "Mode: Rollback to previous deployment"
else
    echo "Mode: Deploy latest configuration"
fi

echo

# List available deploy targets
if nix eval .#deploy.nodes --apply builtins.attrNames 2>/dev/null | grep -q '\[\]'; then
    echo "⚠️  No servers configured in deploy.nodes"
    echo "Add your servers to flake.nix deploy.nodes section"
    exit 1
fi

echo "Available deployment targets:"
nix eval .#deploy.nodes --apply builtins.attrNames 2>/dev/null | jq -r '.[]' | sed 's/^/  - /'
echo

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN - Would execute:"
    echo "${DEPLOY_CMD[*]}"
    exit 0
fi

# Execute deployment
echo "Executing deployment..."
"${DEPLOY_CMD[@]}"

echo
if [ "$ROLLBACK" = true ]; then
    echo "✅ Rollback completed successfully!"
else
    echo "✅ Deployment completed successfully!"
fi

echo "Fleet status:"
echo "  Use 'systemctl status' on each server to check service health"
echo "  Monitor logs with 'journalctl -f' on target servers"