---
id: decision-3
title: Use Colmena for Fleet Deployment
date: '2025-08-24 21:44'
status: proposed
---
## Context

The Cistern project needs to deploy and manage NixOS configurations across multiple mini PC devices remotely. We need a tool that can handle fleet updates, rollbacks, and monitoring for distributed media servers.

## Decision

Use Colmena for NixOS fleet deployment and management.

## Rationale

- Simple, stateless deployment tool designed for NixOS
- No central state management required (unlike NixOps)
- Easy rollbacks with built-in safety mechanisms
- Parallel deployment to multiple hosts
- Integrates well with flakes and standard NixOS workflows
- Good fit for small to medium-sized fleets

## Consequences

**Positive:**
- Simple to use, no state management overhead
- Good rollback support with built-in safety mechanisms
- Parallel deployments improve efficiency for fleet updates
- Integrates seamlessly with existing flake-based workflow
- Lightweight tool with minimal infrastructure requirements

**Negative:**
- Less feature-rich than NixOps for complex deployment scenarios
- Fewer advanced deployment strategies available
- Limited to SSH-based deployments

**Neutral:**
- Another tool in the deployment pipeline to learn and maintain
- Requires SSH access to target devices
- Need to configure hive.nix for fleet management

