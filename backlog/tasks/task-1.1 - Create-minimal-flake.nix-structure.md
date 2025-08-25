---
id: task-1.1
title: Create minimal flake.nix structure
status: Done
assignee:
  - '@jconnuck'
created_date: '2025-08-24 22:36'
updated_date: '2025-08-24 22:59'
labels:
  - nixos
  - foundation
dependencies: []
parent_task_id: task-1
priority: high
---

## Description

Create the basic flake.nix file with nixpkgs input and a simple NixOS configuration output. This establishes the foundation for all subsequent configuration.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 flake.nix file exists with proper structure
- [x] #2 nixpkgs input is defined
- [x] #3 Basic NixOS system output is configured
- [x] #4 Flake passes nix flake check
<!-- AC:END -->

## Implementation Plan

1. Create flake.nix with:
   - Description: "Cistern Media Server Fleet"
   - Input: nixpkgs from github:NixOS/nixpkgs/nixos-25.05 (current stable)
   - Output: nixosConfigurations.cistern using x86_64-linux
   - Module reference to ./configuration.nix

2. Create configuration.nix with:
   - Boot loader configuration for UEFI (systemd-boot)
   - Basic system packages (vim, git, htop)
   - System state version: "25.05"

3. Validation steps:
   - Run `nix flake check` to verify structure
   - Ensure flake.lock is created

Key decisions made:
- Using NixOS 25.05 (current stable) for production reliability
- Targeting x86_64-linux for mini PC hardware
- UEFI boot configuration for modern systems
