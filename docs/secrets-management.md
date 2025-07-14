# Cistern Secrets Management Guide

## Overview

Cistern uses [agenix](https://github.com/ryantm/agenix) for secure secrets management. This ensures all sensitive data (API keys, passwords, tokens) are encrypted at rest and only decrypted on the target systems that need them.

## Architecture

### Secret Storage
- Secrets are stored encrypted in `/secrets/*.age` files
- Only systems with the correct age keys can decrypt them
- Secrets are decrypted at runtime to `/run/agenix/`
- Plain text secrets are never stored in git

### Secret Types
- **API Keys**: Service authentication tokens (Sonarr, Radarr, etc.)
- **Passwords**: Admin passwords, database passwords
- **Tokens**: Authentication tokens, session keys
- **Certificates**: SSL/TLS certificates and keys

## Initial Setup

### 1. Generate Age Keys

Each Cistern host needs an age key for decrypting secrets:

```bash
# Automatic generation (done during provisioning)
sudo /run/current-system/sw/bin/cistern-secrets-init

# Manual generation
sudo mkdir -p /etc/cistern
sudo age-keygen -o /etc/cistern/age.key
sudo chmod 600 /etc/cistern/age.key
```

### 2. Extract Public Key

```bash
sudo age-keygen -y /etc/cistern/age.key > /etc/cistern/age.pub
```

### 3. Update secrets.nix

Add the host's public key to `/secrets/secrets.nix`:

```nix
hosts = {
  eden = "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
  media-server-01 = "age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy";
};
```

## Migration from Plain Text

### Automatic Migration

Use the provided migration script to convert existing plain text secrets:

```bash
cd /path/to/cistern
sudo ./scripts/migrate-api-keys.sh
```

This script will:
1. Find all plain text API keys and passwords
2. Encrypt them using the host's age key
3. Create `.age` files in the secrets directory
4. Backup the original files

### Manual Migration

To manually migrate a secret:

```bash
# Read the plain text secret
SECRET_VALUE=$(cat /var/lib/media/auto-config/sonarr-api-key)

# Encrypt it
echo -n "$SECRET_VALUE" | age -r "$(cat /etc/cistern/age.pub)" > secrets/sonarr-api-key.age

# Update secrets.nix if needed
```

## Managing Secrets

### Creating New Secrets

1. **Generate the secret value**:
   ```bash
   # API key (32 character hex)
   cistern-secret-gen api-key 16
   
   # Password (base64 encoded)
   cistern-secret-gen password 32
   
   # Token (URL-safe base64)
   cistern-secret-gen token 24
   ```

2. **Encrypt the secret**:
   ```bash
   echo -n "secret-value" | age -r "age1..." -r "age2..." > secrets/my-secret.age
   ```

3. **Add to secrets.nix**:
   ```nix
   "my-secret.age" = mkSecret (builtins.attrValues hosts) admins;
   ```

4. **Configure in modules**:
   ```nix
   config.cistern.secrets.secrets = {
     "my-secret" = {
       file = ../secrets/my-secret.age;
       owner = "service-user";
       group = "service-group";
       mode = "0440";
     };
   };
   ```

### Updating Existing Secrets

1. **Re-encrypt with new value**:
   ```bash
   echo -n "new-secret-value" | age -r "age1..." > secrets/my-secret.age
   ```

2. **Deploy the changes**:
   ```bash
   ./scripts/deploy.sh
   ```

### Rotating Secrets

1. **Generate new secret**:
   ```bash
   NEW_KEY=$(cistern-secret-gen api-key 16)
   ```

2. **Update encrypted file**:
   ```bash
   echo -n "$NEW_KEY" | age -r "age1..." > secrets/service-api-key.age
   ```

3. **Deploy and restart service**:
   ```bash
   ./scripts/deploy.sh
   sudo systemctl restart service-name
   ```

## Service-Specific Configuration

### Media Services

API keys for media services are automatically managed:

- **Location**: `/run/agenix/[service]-api-key`
- **Owner**: `media:media`
- **Permissions**: `0440`

Services check for agenix secrets first, then fall back to generating new ones if needed.

### Manual API Key Setting

To manually set an API key for a service:

1. **Get the current key** (if exists):
   ```bash
   sudo cat /run/agenix/sonarr-api-key
   ```

2. **Or generate a new one**:
   ```bash
   API_KEY=$(cistern-secret-gen api-key 16)
   ```

3. **Encrypt and save**:
   ```bash
   echo -n "$API_KEY" | sudo age -r "$(cat /etc/cistern/age.pub)" > secrets/sonarr-api-key.age
   ```

4. **Update service configuration**:
   - The service will automatically use the new key on next restart
   - Or manually update via the service's web UI

### Accessing Secrets in Services

Services can read decrypted secrets from `/run/agenix/`:

```bash
# In a systemd service
API_KEY=$(cat /run/agenix/service-api-key)

# In a script with fallback
if [ -f "/run/agenix/service-api-key" ]; then
    API_KEY=$(cat /run/agenix/service-api-key)
else
    API_KEY=$(generate_new_key)
fi
```

## Security Best Practices

### Do's
- ✅ Store age private keys securely (`chmod 600`)
- ✅ Use different secrets for each service
- ✅ Rotate secrets regularly
- ✅ Backup age keys securely (encrypted)
- ✅ Use strong, randomly generated secrets
- ✅ Commit only `.age` files to git

### Don'ts
- ❌ Never commit plain text secrets
- ❌ Never share age private keys
- ❌ Don't use predictable secret values
- ❌ Don't store secrets in environment variables
- ❌ Don't log secret values

## Troubleshooting

### Check Secret Status

```bash
# List all managed secrets
cistern-secrets-check

# Check if a specific secret is available
ls -la /run/agenix/

# Verify secret permissions
stat /run/agenix/sonarr-api-key
```

### Common Issues

1. **"No such file or directory" for secret**
   - Ensure the secret is defined in both `secrets.nix` and the module
   - Check that agenix service has run: `systemctl status agenix`

2. **"Permission denied" accessing secret**
   - Verify the service user matches the secret's owner
   - Check file permissions in the secret definition

3. **"Failed to decrypt" errors**
   - Ensure the host's public key is in `secrets.nix`
   - Verify the age private key exists at `/etc/cistern/age.key`

4. **Service can't find API key**
   - Check service is configured to look in `/run/agenix/`
   - Ensure secret name matches exactly
   - Verify service starts after `agenix.service`

## Advanced Usage

### Multi-Admin Access

Add admin public keys to `secrets.nix`:

```nix
admins = [
  "age1admin1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  "age1admin2yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
];
```

### Host-Specific Secrets

Create secrets only certain hosts can decrypt:

```nix
"prod-secret.age" = mkSecret [ hosts.prod-server ] admins;
"dev-secret.age" = mkSecret [ hosts.dev-server ] admins;
```

### Emergency Recovery

If you lose access to secrets:

1. **Restore from backup** (if available)
2. **Generate new secrets** and update all services
3. **Re-key existing secrets** with new age keys

Always maintain secure backups of:
- Age private keys
- Critical secrets (encrypted)
- Service configurations