# Cistern Fleet Management Improvements

## Current Milestone: Secrets Management Security Enhancement

### Analysis Summary
After analyzing the Cistern codebase security, I've identified critical vulnerabilities:

**Security Issues Found:**
- API keys stored as plain text files in `/var/lib/media/auto-config/`
- Admin passwords stored unencrypted in `/var/lib/cistern/auth/admin-password.txt`
- No encryption for secrets at rest
- Secrets generated at runtime but stored insecurely

**Implementation Approach:**
Using agenix for NixOS secrets management to provide:
- Encryption at rest for all secrets
- Easy key rotation capabilities
- Backwards compatibility during migration
- Simple, declarative secret management

### Sprint 1: Core Secrets Infrastructure ✓
- [x] Add agenix to flake.nix inputs
- [x] Create /modules/secrets.nix with core functionality
- [x] Implement age key generation utilities
- [x] Add secret encryption/decryption helpers
- [x] Create migration detection system

### Sprint 2: API Key Management ✓
- [x] Update auto-config.nix to use agenix secrets
- [x] Implement encrypted API key storage
- [x] Add runtime secret injection for services
- [x] Create API key rotation utilities
- [x] Maintain backwards compatibility mode

### Sprint 3: Authentication Secrets ✓
- [x] Update auth.nix to use encrypted passwords
- [x] Migrate admin password storage to agenix
- [x] Update user management scripts for encrypted storage
- [x] Implement secure password generation
- [x] Add password rotation capabilities

### Sprint 4: Documentation & Migration Tools ✓
- [x] Create comprehensive secrets management guide
- [x] Write age key generation documentation
- [x] Document secret rotation procedures
- [x] Create migration scripts from plain text
- [x] Add troubleshooting guide

### Sprint 5: Security Hardening
- [ ] Remove plain text fallback after migration period
- [ ] Implement secret access auditing
- [ ] Add automatic secret backup
- [ ] Create disaster recovery procedures
- [ ] Final security audit

## Previous Milestone: Fleet Management Automation & Scaling Improvements

### Analysis Summary
After analyzing the current Cistern fleet management system, I've identified the following:

**Current State:**
- Basic inventory management exists with YAML-based inventory file
- Manual fleet deployment using deploy-rs
- Limited automation for multi-server management
- No automatic service distribution or load balancing
- No fleet-wide health monitoring or rollback capabilities
- Manual process for adding new servers to the fleet

**Key Areas for Improvement:**
1. Automated fleet discovery and registration
2. Service distribution and failover capabilities
3. Fleet-wide configuration synchronization
4. Centralized monitoring and alerting
5. Automated scaling based on load/availability
6. Role-based server management

### Sprint 1: Enhanced Inventory Management
- [ ] Add server health status tracking to inventory.yaml
- [ ] Create inventory validation with server connectivity checks
- [ ] Add automatic inventory updates from deployed servers
- [ ] Implement server tagging and grouping capabilities
- [ ] Add fleet-wide configuration templates

### Sprint 2: Automated Fleet Discovery & Registration
- [ ] Create automatic server discovery via mDNS/Avahi
- [ ] Implement self-registration endpoint for new servers
- [ ] Add SSH key distribution automation
- [ ] Create server capability detection (CPU, RAM, storage)
- [ ] Implement automatic hardware profile selection

### Sprint 3: Service Distribution & Load Balancing
- [ ] Create service placement strategy module
- [ ] Implement primary/replica service distribution
- [ ] Add automatic failover capabilities
- [ ] Create shared storage coordination for services
- [ ] Implement service health checks and auto-restart

### Sprint 4: Fleet-Wide Monitoring & Management
- [ ] Create centralized Prometheus configuration
- [ ] Implement fleet-wide dashboard with Grafana
- [ ] Add automated alerting for service failures
- [ ] Create fleet status CLI command
- [ ] Implement rolling deployment capabilities

### Sprint 5: Advanced Automation Features
- [ ] Create auto-scaling based on resource usage
- [ ] Implement automatic backup distribution
- [ ] Add fleet-wide configuration sync
- [ ] Create disaster recovery automation
- [ ] Implement zero-downtime updates

## Completed Milestones