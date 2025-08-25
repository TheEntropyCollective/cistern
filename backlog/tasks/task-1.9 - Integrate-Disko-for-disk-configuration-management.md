---
id: task-1.9
title: Integrate Disko for disk configuration management
status: To Do
assignee: []
created_date: '2025-08-24 23:17'
updated_date: '2025-08-24 23:17'
labels:
  - disko
  - infrastructure
  - disk-management
dependencies: []
parent_task_id: task-1
priority: high
---

## Description

Add Disko to the flake inputs and create declarative disk configurations for automatic partitioning and formatting. This replaces the temporary filesystem placeholder and enables reproducible disk setups across different hardware.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Disko added as flake input with nixpkgs following,Disko NixOS module integrated,Basic disk configuration created (GPT with EFI and root partitions),Filesystem placeholder removed from configuration.nix,Configuration supports standard mini PC hardware (UEFI boot)
- [ ] #2 Disko added as flake input with nixpkgs following,Disko NixOS module integrated,Basic disk configuration created (GPT with EFI and root partitions),Filesystem placeholder removed from configuration.nix,Configuration supports standard mini PC hardware (UEFI boot)
<!-- AC:END -->
