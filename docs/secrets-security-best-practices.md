# Cistern Secrets Security Best Practices

## Overview

This document outlines security best practices for managing secrets in Cistern deployments. Following these guidelines helps ensure the confidentiality, integrity, and availability of sensitive data across your media server fleet.

## Table of Contents

1. [Key Rotation Procedures](#key-rotation-procedures)
2. [Access Control Guidelines](#access-control-guidelines)
3. [Incident Response](#incident-response)
4. [Compliance Considerations](#compliance-considerations)
5. [Security Monitoring](#security-monitoring)
6. [Operational Security](#operational-security)

## Key Rotation Procedures

### Regular Rotation Schedule

Establish a regular rotation schedule for all secrets:

- **API Keys**: Rotate every 90 days
- **Admin Passwords**: Rotate every 30 days
- **Service Passwords**: Rotate every 180 days
- **Age Encryption Keys**: Rotate annually or after personnel changes

### Rotation Process

1. **Generate New Secret**
   ```bash
   # Generate new API key
   cistern-secret-gen api-key 32
   
   # Generate new password
   cistern-secret-gen password 24
   ```

2. **Encrypt with Age**
   ```bash
   # Encrypt the new secret
   echo -n "new-secret-value" | age -r $(cat /etc/cistern/age.pub) > secrets/service-api-key.age
   ```

3. **Update Configuration**
   ```nix
   # Update the secret reference in your configuration
   cistern.secrets.secrets = {
     "service-api-key" = {
       file = ../secrets/service-api-key.age;
       owner = "media";
       group = "media";
       mode = "0440";
     };
   };
   ```

4. **Deploy Changes**
   ```bash
   # Deploy to all servers
   ./scripts/deploy.sh
   ```

5. **Verify Services**
   - Check service logs for authentication errors
   - Test service connectivity
   - Monitor for failed API calls

### Emergency Rotation

In case of suspected compromise:

1. **Immediately rotate affected secrets**
2. **Deploy to all servers using priority deployment**
3. **Audit access logs for unauthorized use**
4. **Document the incident**

## Access Control Guidelines

### Principle of Least Privilege

- Grant minimum necessary permissions
- Use service-specific users and groups
- Restrict secret access by service

### File Permissions

All secrets must have restrictive permissions:

```bash
# Encrypted secrets (runtime)
chmod 0400 /run/agenix/*

# Age keys
chmod 0600 /etc/cistern/age.key

# Never use world-readable permissions
```

### User Access Management

1. **Administrative Access**
   - Limit root access to essential personnel
   - Use sudo for privilege escalation
   - Log all administrative actions

2. **Service Accounts**
   - Each service runs as its own user
   - Services cannot read other services' secrets
   - No shared credentials between services

3. **SSH Key Management**
   ```nix
   cistern.ssh.authorizedKeys = [
     "ssh-rsa AAAA... user@hostname"  # Add only trusted keys
   ];
   ```

## Incident Response

### Compromised Secrets Response Plan

1. **Detection**
   - Monitor security logs: `/var/log/cistern/secrets-security.log`
   - Watch for authentication failures
   - Alert on unexpected secret access

2. **Containment**
   - Immediately rotate compromised secrets
   - Disable affected service accounts
   - Block suspicious IP addresses

3. **Investigation**
   ```bash
   # Check access logs
   grep "PLAIN TEXT" /var/log/cistern/secrets-access.log
   
   # Review authentication attempts
   journalctl -u cistern-secrets-monitor --since "1 hour ago"
   
   # Audit file access times
   find /var/lib -name "*.txt" -type f -printf '%t %p\n' | grep -E '(key|password)'
   ```

4. **Recovery**
   - Generate all new secrets
   - Deploy fresh configurations
   - Verify service functionality
   - Update access controls

5. **Documentation**
   - Document timeline of events
   - Record affected systems
   - Note remediation steps
   - Update security procedures

### Security Breach Indicators

Watch for these warning signs:

- Unexpected authentication failures
- Secrets accessed at unusual times
- Modified secret files
- New or unknown SSH connections
- Abnormal service behavior

## Compliance Considerations

### Data Protection Requirements

1. **Encryption at Rest**
   - All secrets encrypted using age
   - No plain text storage after migration
   - Secure key management practices

2. **Encryption in Transit**
   - Use SSH for all deployments
   - HTTPS for web interfaces
   - Encrypted service communication

3. **Access Logging**
   - Log all secret access attempts
   - Maintain audit trail for 90 days
   - Regular log review process

### Industry Standards

Align with relevant standards:

- **PCI DSS**: For payment-related systems
- **HIPAA**: If handling health information
- **SOC 2**: For service organizations
- **ISO 27001**: Information security management

### Audit Preparation

1. **Documentation**
   - Maintain current security policies
   - Document all procedures
   - Keep incident response records

2. **Evidence Collection**
   ```bash
   # Generate compliance report
   cistern-secrets-validate > /tmp/security-audit.txt
   
   # Export access logs
   tar -czf secrets-logs-$(date +%Y%m%d).tar.gz /var/log/cistern/
   ```

3. **Regular Reviews**
   - Quarterly security assessments
   - Annual penetration testing
   - Continuous monitoring

## Security Monitoring

### Automated Monitoring

Enable built-in monitoring features:

```nix
cistern.secrets = {
  enableSecurityWarnings = true;
  enableAccessLogging = true;
};
```

### Log Analysis

Regular review of security logs:

```bash
# Check for security warnings
grep "WARNING\|CRITICAL" /var/log/cistern/secrets-security.log

# Monitor access patterns
tail -f /var/log/cistern/secrets-access.log

# Daily audit summary
grep "$(date +%Y-%m-%d)" /var/log/cistern/secrets-audit.log
```

### Alerting

Set up alerts for:

- Plain text secrets detected
- Failed authentication attempts
- Unusual access patterns
- Permission changes
- Missing encrypted secrets

## Operational Security

### Development Practices

1. **Never commit secrets to git**
   ```bash
   # Add to .gitignore
   *.txt
   *.key
   *.password
   secrets/*
   !secrets/*.age
   ```

2. **Use environment separation**
   - Development secrets differ from production
   - Test with non-production data
   - Isolate environments

3. **Code Reviews**
   - Review for hardcoded secrets
   - Check for secure practices
   - Validate permission settings

### Deployment Security

1. **Secure Channels**
   - Deploy only over SSH
   - Verify host fingerprints
   - Use deployment keys

2. **Validation Steps**
   ```bash
   # Pre-deployment check
   cistern-secrets-validate
   
   # Post-deployment verification
   cistern-secrets-status
   ```

3. **Rollback Procedures**
   - Keep previous secret versions
   - Test rollback process
   - Document dependencies

### Backup Security

1. **Encrypted Backups**
   - Backup age-encrypted secrets
   - Never backup plain text
   - Secure backup storage

2. **Recovery Testing**
   - Regular restore drills
   - Verify backup integrity
   - Update recovery docs

### Personnel Security

1. **Access Reviews**
   - Quarterly access audits
   - Remove departed users
   - Update SSH keys

2. **Training**
   - Security awareness training
   - Secret handling procedures
   - Incident response drills

3. **Separation of Duties**
   - Split sensitive operations
   - Require approval for changes
   - Log all actions

## Quick Reference

### Daily Tasks
- Review security logs
- Check for warnings/alerts
- Verify service health

### Weekly Tasks
- Run security validation
- Review access patterns
- Update documentation

### Monthly Tasks
- Rotate admin passwords
- Audit user access
- Test incident response

### Quarterly Tasks
- Rotate API keys
- Security assessment
- Update procedures

### Annual Tasks
- Rotate age keys
- Penetration testing
- Policy review

## Emergency Contacts

Maintain a list of contacts for security incidents:

- Security team lead
- System administrators
- Compliance officer
- External security consultant

Remember: Security is an ongoing process, not a one-time setup. Regular reviews and updates ensure continued protection of your Cistern deployment.