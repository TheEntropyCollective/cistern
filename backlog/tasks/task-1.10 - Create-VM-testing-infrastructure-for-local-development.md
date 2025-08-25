---
id: task-1.10
title: Create VM testing infrastructure for local development
status: To Do
assignee: []
created_date: '2025-08-25 03:38'
updated_date: '2025-08-25 03:38'
labels:
  - testing
  - virtualization
  - development
  - nixos-generators
dependencies:
  - task-1.4
parent_task_id: task-1
priority: high
---

## Description

Set up the ability to test the Cistern NixOS configuration locally on macOS using virtual machines. This includes creating bootable ISO images and VM configurations that can be run in UTM or QEMU for testing the media server stack before deployment to physical hardware.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 nixos-generators integrated as flake input,ISO build output added to flake.nix,VM-specific configuration module created (guest tools and networking),ISO can be built with 'nix build .#cistern-iso' command,Clear documentation for running in UTM on macOS,Services (Jellyfin etc.) accessible from host machine,Testing workflow documented in project docs
- [ ] #2 nixos-generators integrated as flake input,ISO build output added to flake.nix,VM-specific configuration module created (guest tools and networking),ISO can be built with 'nix build .#cistern-iso' command,Clear documentation for running in UTM on macOS,Services (Jellyfin etc.) accessible from host machine,Testing workflow documented in project docs
<!-- AC:END -->

## Implementation Notes

Should work on both Apple Silicon and Intel Macs. UTM is preferred for Apple Silicon due to native virtualization. Consider both ISO and direct VM image outputs. Include minimal disk/RAM requirements in docs.
