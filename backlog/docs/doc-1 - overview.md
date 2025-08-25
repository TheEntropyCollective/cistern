---
id: doc-1
title: overview
type: plan
created_date: '2025-08-24 21:32'
---

    Essential (MVP):
    - NixOS flake with Nixarr module (pre-integrated media stack)
    - Single USB installer that works on any mini PC
    - Auto-provisions on boot (partitions disk, installs, configures)
    - Hostname from MAC address (or custom mapping)
    - Jellyfin + core *arr services working out of box
    - Tailscale auto-join for remote access

    Important (Phase 2):
    - Colmena for fleet updates (deploy to multiple devices)
    - Host customization via overrides (for power users)
    - Multiple profiles (minimal/standard/full)
    - Agenix for secrets (Tailscale auth key, API keys)

    Nice to Have (Phase 3):
    - Hardware auto-detection and optimization
    - Advanced monitoring (Netdata/Prometheus)
    - Backup strategies
    - Web dashboard

    Key Technical Decisions

    - Nixarr - Don't reinvent the wheel, use proven media stack
    - Disko - Declarative disk partitioning
    - Colmena - Simple fleet deployment
    - nixos-generators - Standard ISO creation
    - Agenix - NixOS-native secrets

    The Real Goal

    Friends get a mini PC, boot from USB, wait 10 minutes, have their own Netflix with automated content. You can
    manage/update all devices remotely via Tailscale + Colmena.

    Start simple: Get ONE server working with Jellyfin, then add complexity.

