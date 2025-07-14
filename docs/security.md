# Cistern Security Guide

## Overview

Cistern implements multiple layers of security to protect your media server fleet. This guide covers authentication, password management, and security best practices.

## Authentication

### Web Interface Authentication

All Cistern web services are protected by authentication. The system supports two methods:

1. **Basic Authentication** (default) - Simple htpasswd-based authentication
2. **Authentik SSO** - Advanced single sign-on with 2FA support

### Default Security Behavior

When deploying Cistern:

1. **No hardcoded passwords** - The system never uses predictable default passwords
2. **Auto-generated admin password** - If no password is configured, a cryptographically secure password is generated
3. **Bcrypt hashing** - All passwords are hashed using bcrypt with cost factor 10
4. **SSH key-only for system users** - Root and nixos users have password authentication disabled

## Password Management

### Generating Password Hashes

Use the provided script to generate secure bcrypt hashes:

```bash
./scripts/generate-password-hash.sh [username] [password]
```

If you don't provide arguments, the script will prompt for them securely.

### Setting Admin Password

#### Via Terraform

Add to your terraform.tfvars:

```hcl
admin_password_hash = "$2y$10$..." # Generated hash from script
```

#### Via NixOS Configuration

In your host configuration:

```nix
cistern.auth = {
  enable = true;
  users = {
    "admin" = "$2y$10$..."; # Generated hash
    "user2" = "$2y$10$..."; # Additional users
  };
};
```

### Auto-Generated Passwords

If no admin password is configured:

1. A secure 22-character password is generated using OpenSSL
2. The password is saved to `/var/lib/cistern/auth/admin-password.txt` (root-only access)
3. The password is displayed during initial deployment
4. You should change this password after first login

## SSH Security

### SSH Access Configuration

SSH access is configured for deployment but secured by default:

```nix
cistern.ssh = {
  enable = true;
  enablePasswordAuth = true;  # For initial deployment only
  authorizedKeys = [
    "ssh-rsa AAAA... your-key"
  ];
};
```

### User Account Security

- **Root account**: Password authentication disabled (SSH key only)
- **Nixos account**: Password authentication disabled (SSH key only)
- **Sudo access**: Passwordless sudo for wheel group (deployment convenience)

To set a password for emergency console access:

```nix
users.users.root.hashedPassword = "$6$..."; # SHA-512 hash
```

Generate SHA-512 hashes with: `mkpasswd -m sha-512`

## Security Best Practices

### 1. Change Default Passwords

Always change auto-generated passwords after first login:

```bash
# On the server
sudo cistern-user-manager password admin
```

### 2. Use Strong Passwords

- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, and symbols
- Avoid dictionary words and personal information

### 3. Limit Network Access

Configure firewall rules to restrict access:

```nix
cistern.auth.allowedIPs = [
  "192.168.1.0/24"  # Local network only
];
```

### 4. Enable SSL/TLS

For production deployments, enable SSL:

```nix
cistern.ssl = {
  enable = true;
  acme = {
    enable = true;
    email = "admin@example.com";
  };
};
```

### 5. Regular Updates

Keep your system updated:

```bash
./scripts/deploy.sh --upgrade
```

### 6. Monitor Access Logs

Check authentication logs regularly:

```bash
# View recent auth attempts
journalctl -u auth-monitor -n 50

# Check failed login attempts
grep "401\|403" /var/log/nginx/access.log
```

## Terraform Security

### Sensitive Variables

Mark password-related variables as sensitive:

```hcl
variable "admin_password_hash" {
  type      = string
  sensitive = true
}
```

### State File Security

Terraform state may contain sensitive data:

1. Use remote state with encryption
2. Restrict access to state files
3. Never commit state files to git

## Emergency Access

If you're locked out:

1. **Physical/console access**: Boot into single-user mode
2. **Via another admin**: Use cistern-user-manager to reset passwords
3. **Redeploy**: Use nixos-anywhere to redeploy with new credentials

## Security Checklist

Before deploying to production:

- [ ] Generate strong admin password hash
- [ ] Configure SSH keys for all administrators  
- [ ] Disable password authentication after deployment
- [ ] Configure firewall rules
- [ ] Enable SSL/TLS certificates
- [ ] Set up log monitoring
- [ ] Document emergency access procedures
- [ ] Test backup and recovery procedures

## Reporting Security Issues

If you discover a security vulnerability:

1. Do not open a public issue
2. Email security details to the maintainers
3. Include steps to reproduce
4. Allow time for a fix before disclosure