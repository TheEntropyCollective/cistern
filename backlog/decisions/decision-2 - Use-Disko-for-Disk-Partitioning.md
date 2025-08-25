---
id: decision-2
title: Use Disko for Disk Partitioning
date: '2025-08-24 21:43'
status: proposed
---
## Context

The Cistern project requires automatic disk partitioning and formatting during zero-touch provisioning. We need a declarative, reproducible way to handle different storage configurations (single SSD, SSD+HDD) across various mini PC hardware.

## Decision

Use Disko for declarative disk partitioning and formatting.

## Rationale

- Declarative configuration in Nix language
- Reproducible disk layouts across different hardware
- Supports complex partitioning schemes (EFI, swap, multiple drives)
- Integrates seamlessly with NixOS installation process
- Active development and community support

## Consequences

**Positive:**
- Deterministic installs across all hardware configurations
- Supports multiple storage layouts (single SSD, SSD+HDD combinations)
- Version-controlled disk configurations alongside system configs
- Reduces human error in manual partitioning
- Integrates natively with NixOS installation process

**Negative:**
- Learning curve for complex partitioning setups
- Less flexibility than manual partitioning for edge cases
- Dependency on Disko module maintenance and updates
- Abstracts away low-level disk operations

**Neutral:**
- Another tool to learn in the NixOS ecosystem
- Adds abstraction layer over traditional partitioning tools
- Requires understanding of Disko-specific configuration syntax

