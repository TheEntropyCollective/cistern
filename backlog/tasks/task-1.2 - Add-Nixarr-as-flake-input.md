---
id: task-1.2
title: Add Nixarr as flake input
status: Done
assignee:
  - '@jconnuck'
created_date: '2025-08-24 22:36'
updated_date: '2025-08-25 00:02'
labels:
  - nixarr
  - integration
dependencies: []
parent_task_id: task-1
priority: high
---

## Description

Integrate the Nixarr module repository as a flake input and pass it to the NixOS configuration modules.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Nixarr input added to flake.nix
- [x] #2 Nixarr module passed to NixOS configuration
- [x] #3 Flake lock file updated with Nixarr
- [x] #4 Configuration still builds successfully
<!-- AC:END -->

## Implementation Plan

### 1. Update flake.nix inputs
- Add Nixarr as an input: `nixarr.url = "github:rasmus-kirk/nixarr"`
- Ensure it follows the same nixpkgs version for consistency

### 2. Update flake.nix outputs
- Add nixarr to the outputs function parameters
- Include `nixarr.nixosModules.default` in the modules list
- Pass nixarr through specialArgs for potential module access

### 3. Add Nixarr configuration structure
- Create basic nixarr configuration block in configuration.nix
- Set `nixarr.enable = false` initially (will enable in later tasks)
- Define standard directories:
  - mediaDir = "/data/media"
  - stateDir = "/data/media/.state/nixarr"
- Add comments for future service enablement

### 4. Validation steps
- Run `nix flake update` to lock Nixarr dependency
- Run `nix flake check` to validate configuration
- Verify flake.lock includes Nixarr entry

### Technical Notes
- Nixarr uses `nixarr.nixosModules.default` as its main module export
- All Nixarr services are configured under the `nixarr` namespace
- Secrets should be stored outside git (typically in `/data/.secret/`)
- Services include: Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr, Lidarr, Readarr, Transmission, Jellyseerr

## Implementation Notes

All acceptance criteria validated and completed:
- AC #1: ✅ Nixarr input present in flake.nix with github:rasmus-kirk/nixarr
- AC #2: ✅ Nixarr module included in modules list as nixarr.nixosModules.default  
- AC #3: ✅ flake.lock contains Nixarr entry with commit hash and dependencies
- AC #4: ✅ Configuration validates successfully with nix flake check
