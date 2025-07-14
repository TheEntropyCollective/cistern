# Cistern Secrets Migration Guide

This guide provides comprehensive instructions for migrating from plain text secrets to encrypted secrets using agenix in Cistern.

## Table of Contents

1. [Overview](#overview)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Step-by-Step Migration](#step-by-step-migration)
4. [Troubleshooting](#troubleshooting)
5. [Rollback Procedures](#rollback-procedures)
6. [Security Considerations](#security-considerations)
7. [Post-Migration Verification](#post-migration-verification)

## Overview

Cistern's secrets management system migrates sensitive data from plain text files to encrypted agenix secrets. This provides:

- **Encryption at rest** for all secrets
- **Easy key rotation** capabilities
- **Secure distribution** to authorized hosts
- **Git-safe storage** of encrypted secrets
- **Backwards compatibility** during migration

### Secret Types

The migration covers three main categories:

1. **API Keys**: Media service authentication tokens
   - Sonarr, Radarr, Prowlarr, Bazarr, Jellyfin
   - SABnzbd, Transmission

2. **Authentication Secrets**: User and service passwords
   - Admin dashboard password
   - Authentik database and admin passwords
   - SMTP credentials

3. **Service Tokens**: Internal service communication
   - Authentik secret key
   - Future webhook tokens

## Pre-Migration Checklist

Before starting migration, ensure:

- [ ] **Backup existing secrets**: Create a secure backup of all plain text secrets
- [ ] **SSH access**: Verify SSH access to all Cistern hosts
- [ ] **Age tools installed**: Ensure `age` and `age-keygen` are available
- [ ] **Git repository access**: Ability to commit encrypted secrets
- [ ] **Service downtime window**: Plan for potential brief service interruptions
- [ ] **Admin SSH key**: Have your SSH public key ready for secret access

### System Requirements

```bash
# Check if age is installed
which age age-keygen

# Verify you're in the Cistern development shell
nix develop

# Check current secret status
sudo cistern-secrets-check
```

## Step-by-Step Migration

### 1. Backup Existing Secrets

First, create a secure backup of all plain text secrets:

```bash
# Create backup directory
sudo mkdir -p /root/cistern-secrets-backup
sudo chmod 700 /root/cistern-secrets-backup

# Backup all secrets
sudo ./scripts/migrate-all-secrets.sh --backup-only

# Verify backup
sudo ls -la /root/cistern-secrets-backup/
```

### 2. Generate Age Keys

Each host needs an age key for decrypting secrets:

```bash
# Generate age keys for the current host
sudo ./scripts/generate-age-keys.sh

# View the generated public key
sudo cat /etc/cistern/age.pub
```

### 3. Update secrets.nix Configuration

Add your admin SSH key and host public keys to `/secrets/secrets.nix`:

```nix
let
  # Add your SSH public key here
  admins = [
    "ssh-rsa AAAAB3NzaC1yc2E... your-key@hostname"
  ];

  # Add host age public keys
  hosts = {
    eden = "age1...";  # From /etc/cistern/age.pub on eden
    # Add more hosts as needed
  };
```

### 4. Run Migration Scripts

Execute the complete migration:

```bash
# Run the all-in-one migration script
sudo ./scripts/migrate-all-secrets.sh

# Or migrate individually:
sudo ./scripts/migrate-api-keys.sh
sudo ./scripts/migrate-auth-secrets.sh
```

### 5. Validate Migration

Verify all secrets were migrated successfully:

```bash
# Check migration status
sudo ./scripts/validate-secrets.sh

# Test secret decryption
sudo age -d -i /etc/cistern/age.key /Users/jconnuck/cistern/secrets/admin-password.age
```

### 6. Commit Encrypted Secrets

The encrypted secrets are safe to commit to git:

```bash
# Add encrypted secrets
git add secrets/*.age secrets/secrets.nix

# Commit the changes
git commit -m "Add encrypted secrets"
```

### 7. Deploy Updated Configuration

Deploy the new configuration to use encrypted secrets:

```bash
# Deploy to specific host
./scripts/deploy.sh eden

# Or deploy to all hosts
./scripts/deploy.sh
```

### 8. Verify Services

Check that all services are running correctly:

```bash
# Check service status
ssh eden 'systemctl status media-server.target'

# Access the dashboard
curl -I http://eden/
```

### 9. Clean Up Plain Text Secrets

After verifying everything works, remove plain text secrets:

```bash
# Remove plain text secrets (after verification!)
sudo rm -f /var/lib/media/auto-config/*.txt
sudo rm -f /var/lib/cistern/auth/admin-password.txt
sudo rm -rf /var/lib/cistern/authentik/
```

## Troubleshooting

### Common Issues

#### Age Key Not Found
```bash
Error: age key not found at /etc/cistern/age.key
```
**Solution**: Generate the age key:
```bash
sudo mkdir -p /etc/cistern
sudo age-keygen -o /etc/cistern/age.key
sudo chmod 600 /etc/cistern/age.key
```

#### Permission Denied Errors
```bash
Error: Permission denied accessing /run/agenix/
```
**Solution**: Ensure services run with correct permissions:
```bash
# Check agenix directory permissions
sudo ls -la /run/agenix/

# Restart agenix service
sudo systemctl restart agenix
```

#### Service Can't Access Secrets
```bash
Error: Secret file not found: /run/agenix/sonarr-api-key
```
**Solution**: Verify secret is defined in configuration:
1. Check that the secret exists in `/secrets/`
2. Verify it's referenced in the host's secrets configuration
3. Ensure the service user has read permissions

#### Decryption Failures
```bash
Error: failed to decrypt: no identity matched
```
**Solution**: Verify keys are correctly configured:
```bash
# Check if host key matches secrets.nix
sudo age-keygen -y /etc/cistern/age.key

# Ensure this key is in secrets.nix hosts section
```

### Debug Commands

```bash
# List all encrypted secrets
ls -la /Users/jconnuck/cistern/secrets/*.age

# Check agenix runtime directory
sudo ls -la /run/agenix/

# View service environment for secret paths
sudo systemctl show sonarr | grep -E '(Environment|ExecStart)'

# Test manual decryption
sudo age -d -i /etc/cistern/age.key /path/to/secret.age
```

## Rollback Procedures

If issues occur during migration, follow these rollback steps:

### 1. Immediate Rollback

Stop the migration and restore plain text secrets:

```bash
# Restore from backup
sudo cp -r /root/cistern-secrets-backup/* /

# Disable agenix in configuration
# Edit the host configuration and set:
# cistern.secrets.migrationMode = true;

# Redeploy without agenix
./scripts/deploy.sh --rollback
```

### 2. Partial Rollback

Rollback specific services while keeping others encrypted:

```bash
# Restore specific plain text secret
sudo cp /root/cistern-secrets-backup/var/lib/media/auto-config/sonarr-api-key.txt \
        /var/lib/media/auto-config/

# Update service to use plain text temporarily
# The migration mode will automatically detect and use plain text
```

### 3. Complete Removal

Completely remove agenix integration:

1. Remove encrypted secrets:
   ```bash
   rm -f secrets/*.age
   ```

2. Update configuration:
   ```nix
   # In modules/secrets.nix, disable agenix:
   cistern.secrets.enable = false;
   ```

3. Restore all plain text secrets from backup

4. Redeploy configuration

## Security Considerations

### Key Management

1. **Age Key Protection**
   - Store age private keys securely with 600 permissions
   - Never commit private keys to git
   - Consider using hardware security modules for production

2. **Access Control**
   - Limit admin SSH keys to necessary personnel
   - Regularly audit the `admins` list in secrets.nix
   - Remove access for departing administrators promptly

3. **Backup Security**
   - Encrypt backups of plain text secrets
   - Store backups separately from the main system
   - Delete backups after successful migration

### Best Practices

1. **Regular Key Rotation**
   ```bash
   # Rotate a specific secret
   ./scripts/rotate-secret.sh sonarr-api-key
   ```

2. **Audit Access**
   ```bash
   # Check who can decrypt secrets
   grep -A5 "admins =" secrets/secrets.nix
   ```

3. **Monitor Secret Access**
   - Enable systemd journal logging for secret access
   - Set up alerts for unauthorized access attempts

### Security Checklist

- [ ] All plain text secrets removed after migration
- [ ] Age private keys have 600 permissions
- [ ] Admin SSH keys are from trusted sources
- [ ] Backup directory is encrypted or deleted
- [ ] Service accounts have minimal permissions
- [ ] Audit logs are enabled for secret access

## Post-Migration Verification

### Automated Validation

Run the comprehensive validation script:

```bash
sudo ./scripts/validate-secrets.sh --full

# Expected output:
# ✓ All secrets encrypted
# ✓ Services can access secrets
# ✓ No plain text secrets found
# ✓ Age keys properly configured
```

### Manual Service Checks

1. **Media Services**
   ```bash
   # Check API key access
   curl -H "X-Api-Key: $(sudo cat /run/agenix/sonarr-api-key)" \
        http://localhost:8989/api/v3/system/status
   ```

2. **Authentication**
   ```bash
   # Test admin login
   curl -u admin:$(sudo cat /run/agenix/admin-password) \
        http://localhost/
   ```

3. **Database Connections**
   ```bash
   # Verify Authentik database
   sudo -u authentik psql -c "SELECT 1"
   ```

### Monitoring Setup

Enable ongoing monitoring of secret management:

```bash
# Add to Prometheus configuration
- job_name: 'agenix'
  static_configs:
    - targets: ['localhost:9095']
  metric_relabel_configs:
    - source_labels: [__name__]
      regex: 'agenix_.*'
      action: keep
```

## Additional Resources

- [Agenix Documentation](https://github.com/ryantm/agenix)
- [Age Encryption](https://github.com/FiloSottile/age)
- [NixOS Secrets Management](https://nixos.wiki/wiki/Comparison_of_secret_managing_schemes)

For support, check the logs:
```bash
# View agenix logs
journalctl -u agenix -f

# Check service logs for secret-related errors
journalctl -u sonarr -g "secret\|api.*key" --since "1 hour ago"
```