---
id: decision-8
title: Zero-Touch Provisioning Requirements
date: '2025-08-24 22:13'
status: proposed
---
## Context

The Cistern project uses admin-initiated deployment where the admin boots each mini PC with a USB drive to perform initial provisioning. After the 10-minute automated setup, users receive a pre-configured device that requires no configuration, terminal commands, or technical knowledge.



## Decision

Implement zero-touch provisioning where the installer automatically partitions disks, installs the system, configures all services, and joins the management network without user intervention.

## Rationale

- Admin can verify successful deployment before device reaches end user
- Reduces support burden and potential for user error
- Enables reliable deployment with immediate verification of successful setup
- Creates consistent, predictable deployments
- Eliminates need for technical documentation for end users
- Supports the "10 minute Netflix" user experience goal



## Consequences

**Positive:**
- Scalable deployment with zero support burden for basic installs
- Consistent results across all deployed devices
- Minimal technical knowledge required from end users
- Great user experience that builds trust and satisfaction
- Enables mass deployment model to many friends/family

**Negative:**
- Complex installer logic requiring robust hardware detection
- Harder to debug failed installations remotely
- All configuration decisions must be made ahead of time
- Requires extensive testing across different hardware configurations

**Neutral:**
- Less flexibility during initial setup phase
- All customization must happen post-installation via fleet management
- Need for comprehensive error recovery and fallback mechanisms

