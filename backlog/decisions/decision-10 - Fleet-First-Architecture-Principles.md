---
id: decision-10
title: Fleet-First Architecture Principles
date: '2025-08-24 22:15'
status: proposed
---
## Context

The Cistern project is designed to manage multiple media servers deployed across different locations for friends and family. Unlike single-server solutions, we need architecture that scales to dozens of devices with centralized management and consistent configurations.

## Decision

Design the entire system with fleet management as the primary use case, not single device deployment.

## Rationale

- Primary goal is managing 10-50+ devices, not optimizing for single installations
- Centralized configuration management prevents configuration drift
- Remote deployment and updates are essential - no physical access after initial setup
- Consistent experience across all devices in the fleet
- Simplified troubleshooting through standardized configurations
- Scalable onboarding process for adding new devices
- Admin productivity through batch operations and automation

## Consequences

**Positive:**
- Scales to many devices with centralized control
- Consistent fleet management reduces operational overhead
- Standardized configurations enable batch operations
- Remote deployment capabilities eliminate need for physical access
- Simplified troubleshooting through unified architecture

**Negative:**
- More complex initial setup compared to single-device solutions
- Over-engineered for single device use cases
- Requires network connectivity for management operations
- Additional learning curve for fleet management tools

**Neutral:**
- Architecture decisions favor fleet operations over individual device optimization
- Learning curve shifts from individual service configuration to fleet management patterns
- Trade-off between simplicity for single devices and scalability for many devices

