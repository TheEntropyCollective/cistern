---
id: task-1.4
title: Enable Jellyfin via Nixarr
status: Done
assignee: []
created_date: '2025-08-24 22:36'
updated_date: '2025-08-24 22:39'
labels:
  - nixarr
  - jellyfin
  - media
dependencies: []
parent_task_id: task-1
priority: high
---

## Description

Configure and enable Jellyfin media server using the Nixarr module as the first test of the media stack.

## Implementation Plan

### Step 1: Enable Nixarr and Jellyfin Service
- Set `nixarr.enable = true` in configuration.nix
- Add `nixarr.jellyfin.enable = true` to enable the Jellyfin service
- Verify media directories are properly configured (/data/media)

### Step 2: Configure Firewall Rules
- Add port 8096 to allowed TCP ports in modules/base.nix for Jellyfin web interface
- Ensure the firewall configuration is properly integrated

### Step 3: Validate Configuration
- Run `nix flake check` to validate the flake configuration
- Build the configuration with `nixos-rebuild build --flake .#cistern`
- Check for any build errors or warnings

### Step 4: Test Jellyfin Service
- Verify service would start successfully (via build output)
- Confirm port 8096 would be exposed
- Document any additional configuration needed

### Notes
- Using Nixarr's default media directory structure at /data/media
- Jellyfin will be the first service to validate the media stack integration
- After success, we'll proceed with Sonarr, Radarr, and Prowlarr

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Jellyfin service enabled through Nixarr
- [ ] #2 Media directories configured
- [ ] #3 Service starts successfully
- [ ] #4 Web interface accessible on port 8096
<!-- AC:END -->
