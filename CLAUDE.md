# CLAUDE.md - Cistern Media Server Fleet

This file provides guidance to Claude Code when working with the Cistern project.

## Project Overview

Cistern is a NixOS-based media server fleet management system designed for deploying and managing multiple personal media servers for friends and family. Each device runs a complete media automation stack (*arr services) with zero-touch provisioning and remote management capabilities.

Admin boots each mini PC with USB for initial 10-minute provisioning, then friends receive a pre-configured device with their own Netflix and automated content. You manage/update all devices remotely via Tailscale + Colmena.

## Key Features

- **Full Media Stack**: Complete *arr ecosystem (Jellyfin, Sonarr, Radarr, Prowlarr, etc.) via Nixarr
- **Zero-Touch Provisioning**: Single USB installer works for all devices
- **Flexible Customization**: Three tiers from zero-config to full customization
- **Remote Management**: Tailscale mesh network + Colmena deployment
- **Hardware Agnostic**: Auto-detects and configures mini PC hardware

## Architecture Decisions

### Core Technology Stack
- **NixOS**: Declarative system configuration with atomic rollbacks
- **Nixarr**: Battle-tested media server module with pre-integrated services
- **Colmena**: Simple, stateless NixOS deployment tool
- **Disko**: Declarative disk partitioning and formatting
- **nixos-generators**: Standard NixOS ISO creation tooling
- **Tailscale**: Zero-config mesh VPN for device networking
- **Agenix**: NixOS-native secret management

### Design Principles
1. **Standard Tooling**: Prefer established NixOS tools over custom scripts
2. **Deterministic Configuration**: Everything declared in Nix modules
3. **Flexible by Default**: Zero-config works, customization available
4. **Remote First**: Designed for managing distributed devices
5. **Friend-Friendly**: End users only interact with media services

