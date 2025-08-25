---
id: decision-7
title: Friend-Friendly Design Philosophy
date: '2025-08-24 22:13'
status: proposed
---
## Context

The Cistern project is designed to provide media servers to friends and family who are not technical users. These users should never need to interact with NixOS, command lines, or complex configuration - they just want their own Netflix that works.

## Decision

Adopt a "Friend-Friendly" design philosophy where end users only interact with Jellyfin and media services, never the underlying NixOS system.

## Rationale

- Target users are not Linux administrators or technical users
- Success is measured by user adoption and satisfaction, not technical flexibility
- Complexity should be hidden from end users behind simple interfaces
- Admin (you) handles all system management remotely
- User experience should be comparable to consumer streaming services
- Troubleshooting should not require user technical knowledge

## Consequences

**Positive:**
- Higher user adoption and satisfaction
- Fewer support requests from non-technical users
- Better overall user experience
- Clear separation of concerns between admin and end users
- Users can focus on consuming media rather than managing systems

**Negative:**
- Less flexibility for power users who might want system access
- More responsibility placed on the admin for all system management
- Harder to debug user-specific issues without direct system access
- May require more robust monitoring and logging for remote troubleshooting

**Neutral:**
- Need to design all interfaces with non-technical users in mind
- Focus on reliability and "it just works" over advanced features
- Requires careful consideration of user workflows and pain points
- May need to develop user-friendly documentation focused on media consumption rather than technical configuration

