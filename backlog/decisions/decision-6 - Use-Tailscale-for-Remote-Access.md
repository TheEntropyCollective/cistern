---
id: decision-6
title: Use Tailscale for Remote Access
date: '2025-08-24 21:55'
status: proposed
---
## Context

The Cistern project requires secure remote access to manage a fleet of media servers deployed at friends' and family's locations. We need a solution that works behind NATs and firewalls without requiring port forwarding or complex network configuration from end users.

## Decision

Use Tailscale for secure remote access and fleet management.

## Rationale

- Zero-configuration mesh VPN that works behind NATs
- Automatic NAT traversal and firewall handling
- WireGuard-based for performance and security
- Simple device onboarding with auth keys
- Works well with NixOS and can be declaratively configured
- Eliminates need for port forwarding or VPN server setup

## Consequences

**Positive:**
- Zero-config networking for end users
- Automatic NAT traversal and firewall handling
- Secure WireGuard protocol with modern cryptography
- Simple device management and onboarding
- Excellent NixOS integration and declarative configuration
- No need for manual port forwarding or VPN server setup

**Negative:**
- Requires Tailscale account and subscription for larger fleets
- Not fully self-hosted, creates dependency on external service
- Potential privacy concerns with traffic routing through Tailscale infrastructure
- Vendor lock-in risk if Tailscale service changes or becomes unavailable

**Neutral:**
- Another service to manage in the deployment pipeline
- Requires understanding of mesh networking concepts for troubleshooting
- Additional authentication layer to manage (auth keys, device approval)

