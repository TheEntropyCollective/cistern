---
id: decision-1
title: Use Nixarr for Media Stack
date: '2025-08-24 21:43'
status: proposed
---
## Context

The Cistern project needs a complete media server stack including Jellyfin, Sonarr, Radarr, Prowlarr, and other *arr services. Rather than configuring each service individually, we need a proven, pre-integrated solution.

## Decision

Use the Nixarr NixOS module which provides a battle-tested, pre-configured media server ecosystem.

## Rationale

- Proven in production by the NixOS community
- Pre-configured with Trash Guides best practices
- Services are already interconnected and optimized
- Reduces configuration complexity and maintenance burden
- Strong community support and documentation

## Consequences

**Positive:**
- Faster deployment with reduced configuration errors
- Community support and continuous improvements
- Battle-tested configurations reduce debugging time
- Consistent media server deployments across fleet

**Negative:**
- Less flexibility for custom service configurations
- Dependency on external module maintenance
- Need to work within Nixarr's configuration patterns

**Neutral:**
- Need to learn Nixarr-specific options rather than individual service configs
- Additional abstraction layer over raw service configuration

