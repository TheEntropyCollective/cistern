---
id: task-1.3
title: Create base system module
status: Done
assignee: []
created_date: '2025-08-24 22:36'
updated_date: '2025-08-24 23:59'
labels:
  - nixos
  - configuration
dependencies: []
parent_task_id: task-1
priority: high
---

## Description

Implement basic NixOS system settings including hostname, timezone, locale, users, and network configuration.

## Implementation Plan for Task 1.3: Create Base System Module

### Step-by-Step Implementation:

**1. Create Module Structure**
- Create `modules/` directory
- Create `modules/base.nix` with proper NixOS module format
- Set up the module to accept standard parameters (`{ config, pkgs, lib, ... }`)

**2. System Identity Configuration**
- Configure dynamic hostname (will support the river naming strategy in task 2)
- Set timezone to a sensible default (UTC or configurable)
- Configure locale settings (en_US.UTF-8 as default)

**3. User Management**
- Create a default admin user (`cistern` or similar)
- Grant sudo privileges for remote management
- Set up SSH key authentication (prepare for Agenix secrets later)
- Configure shell and basic user environment

**4. Network & Remote Access**
- Enable NetworkManager or systemd-networkd for automatic networking
- Configure firewall with SSH access
- Enable SSH daemon with secure defaults
- Prepare for Tailscale integration (used in task 1.4+)

**5. Integration & Testing**
- Update `flake.nix` to import the new base module
- Remove hardcoded configuration from `configuration.nix`
- Test that the configuration builds with `nix build`
- Verify all acceptance criteria are met

### Key Design Decisions:

- **Modular**: Separate base system from media-specific config
- **Configurable**: Use NixOS options for flexibility across devices
- **Remote-Ready**: SSH and user setup for fleet management
- **Secure Defaults**: Minimal attack surface, prepare for secrets management

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 modules/base.nix file created
- [x] #2 System hostname and timezone configured
- [x] #3 Basic user account created
- [x] #4 Network configuration functional
- [x] #5 SSH access enabled for management
<!-- AC:END -->

## Implementation Plan

### Step-by-Step Implementation:

**1. Create Module Structure** ✓ (COMPLETED)
- Create `modules/` directory ✓ (COMPLETED)
- Create `modules/base.nix` with proper NixOS module format ✓ (COMPLETED)
- Set up the module to accept standard parameters (`{ config, pkgs, lib, ... }`) ✓ (COMPLETED)

**2. System Identity Configuration** ✓ (COMPLETED)
- Configure dynamic hostname (will support the river naming strategy in task 2) ✓ (COMPLETED)
- Set timezone to a sensible default (UTC or configurable) ✓ (COMPLETED)
- Configure locale settings (en_US.UTF-8 as default) ✓ (COMPLETED)

**3. User Management** ✓ (COMPLETED)
- Create a default admin user (`cistern` or similar) ✓ (COMPLETED)
- Grant sudo privileges for remote management ✓ (COMPLETED)
- Set up SSH key authentication (prepare for Agenix secrets later) ✓ (COMPLETED)
- Configure shell and basic user environment ✓ (COMPLETED)

**4. Network & Remote Access** ✓ (COMPLETED)
- Enable NetworkManager or systemd-networkd for automatic networking ✓ (COMPLETED)
- Configure firewall with SSH access ✓ (COMPLETED)
- Enable SSH daemon with secure defaults ✓ (COMPLETED)
- Prepare for Tailscale integration (used in task 1.4+) ✓ (COMPLETED)

**5. Integration & Testing** ✓ (COMPLETED)
- Update `flake.nix` to import the new base module ✓ (COMPLETED)
- Remove hardcoded configuration from `configuration.nix` ✓ (COMPLETED)
- Test that the configuration builds with `nix build` ✓ (COMPLETED)
- Verify all acceptance criteria are met ✓ (COMPLETED)

### Key Design Decisions:
- **Modular**: Separate base system from media-specific config
- **Configurable**: Use NixOS options for flexibility across devices
- **Remote-Ready**: SSH and user setup for fleet management
- **Secure Defaults**: Minimal attack surface, prepare for secrets management

## Implementation Notes

All acceptance criteria validated and completed:
- AC #1: modules/base.nix exists with proper NixOS module structure
- AC #2: Hostname and timezone are configurable via cistern.base options  
- AC #3: Admin user 'cistern' created with sudo and network permissions
- AC #4: NetworkManager enabled with firewall configuration
- AC #5: SSH service enabled with secure settings (key-only auth, no root login)
