# SSH Security Configuration

This document explains the SSH security hardening implemented in Cistern.

## Security Improvements

### 1. SSH Hardening in base.nix

The base SSH configuration now includes comprehensive security hardening:

- **PermitRootLogin**: Changed from `"yes"` to `"prohibit-password"`
  - Root can still login with SSH keys (for deployment automation)
  - Root login with password is completely blocked
  
- **PasswordAuthentication**: Disabled by default
  - Only SSH key authentication is allowed
  - Prevents brute force password attacks

- **Additional Hardening**:
  - `ChallengeResponseAuthentication`: Disabled
  - `KbdInteractiveAuthentication`: Disabled
  - `UsePAM`: Disabled (prevents password fallback)
  - `X11Forwarding`: Disabled (not needed for servers)
  - `MaxAuthTries`: Limited to 3 attempts
  - `ClientAliveInterval`: 5-minute keep-alive
  - `ClientAliveCountMax`: Disconnect after 10 minutes of inactivity

- **Strong Cryptography**:
  - Modern ciphers: ChaCha20-Poly1305, AES-256-GCM
  - Strong MACs: HMAC-SHA2-512-ETM, HMAC-SHA2-256-ETM
  - Secure key exchange: Curve25519-SHA256

- **User Restrictions**:
  - Only specific users allowed: root, media, nixos
  - Prevents unauthorized user access attempts

### 2. Fail2ban Protection

Fail2ban is now enabled to protect against brute force attacks:

- **SSH Jail**: 
  - 3 failed attempts = 2-hour ban
  - Monitors systemd logs for SSH failures
  - Local network IPs are whitelisted

- **General Settings**:
  - 5 retries before banning (default)
  - 1-hour ban time (default)
  - 10-minute window for counting failures

### 3. SSH Deployment Module Security

The ssh-deployment module has been hardened:

- **Password Auth Default**: Changed from `true` to `false`
  - Must be explicitly enabled when needed
  - System shows warnings when enabled
  
- **Root Access**: 
  - Changed to `"prohibit-password"`
  - Root can use SSH keys but never passwords

- **Security Warnings**:
  - NixOS will display warnings when password auth is enabled
  - Reminds administrators to disable after initial setup

## Best Practices

### Initial Deployment

1. **Temporary Password Auth** (if needed):
   ```nix
   cistern.ssh.enablePasswordAuth = true;
   ```
   - Use ONLY during initial provisioning
   - Disable immediately after SSH keys are deployed

2. **Add SSH Keys**:
   ```nix
   cistern.ssh.authorizedKeys = [
     "ssh-rsa YOUR_PUBLIC_KEY_HERE user@host"
   ];
   ```

3. **Disable Password Auth**:
   ```nix
   cistern.ssh.enablePasswordAuth = false;
   ```

### Ongoing Security

1. **Monitor Auth Logs**:
   ```bash
   journalctl -u sshd -f
   journalctl -u fail2ban -f
   ```

2. **Check Banned IPs**:
   ```bash
   fail2ban-client status ssh
   ```

3. **Rotate SSH Keys**:
   - Generate new keys periodically
   - Remove old/unused keys from configuration
   - Use SSH key passphrases

4. **Review Access**:
   - Regularly audit authorized_keys
   - Remove unnecessary user accounts
   - Check AllowUsers list in SSH config

## Emergency Access

If you get locked out:

1. **Physical/Console Access**:
   - Boot from NixOS installer
   - Mount system and fix configuration
   - Rebuild system

2. **Recovery Mode**:
   - Boot into single-user mode
   - Edit `/etc/nixos/configuration.nix`
   - Temporarily enable password auth
   - Add your SSH key

## Security Monitoring

Check for suspicious activity:

```bash
# Failed SSH attempts
journalctl -u sshd | grep "Failed password"
journalctl -u sshd | grep "Invalid user"

# Successful logins
journalctl -u sshd | grep "Accepted publickey"

# Fail2ban actions
fail2ban-client status
fail2ban-client status ssh
```

## Compliance

These settings help meet security requirements for:
- CIS Benchmarks for SSH
- NIST guidelines
- PCI DSS requirements
- General security best practices