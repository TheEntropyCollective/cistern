---
id: decision-5
title: Use Agenix for Secrets Management
date: '2025-08-24 21:54'
status: proposed
---
## Context

The Cistern project needs to manage sensitive information like Tailscale auth keys, media service API keys, and SSH keys across multiple devices. We need a secure, NixOS-native solution that works with declarative configuration.

## Decision

Use Agenix for secrets management in the Cistern fleet.

## Rationale

- NixOS-native secrets management with age encryption
- Git-friendly (encrypted files can be committed safely)
- Integrates seamlessly with NixOS modules and flakes
- Simple key management with SSH/age keys
- Secrets are decrypted at activation time, not build time
- Active community support and good documentation

## Consequences

**Positive:**
- Secure encryption with age cryptography
- Git-friendly encrypted files that can be safely committed
- Seamless integration with NixOS modules and flakes
- Simple workflow for secret management and distribution

**Negative:**
- Requires careful key management and backup procedures
- Learning curve for age encryption tooling and concepts

**Neutral:**
- Another tool in the stack to maintain and understand
- Adds complexity to secret handling workflow compared to plain files

