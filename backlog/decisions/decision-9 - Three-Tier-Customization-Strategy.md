---
id: decision-9
title: Three-Tier Customization Strategy
date: '2025-08-24 22:14'
status: proposed
---
## Context

The Cistern project serves users with different technical skill levels and customization needs. We need to balance simplicity for beginners with flexibility for power users, while maintaining the zero-touch provisioning goal.

## Decision

Implement a three-tier customization approach with phased rollout: Start with Level 1 (Zero-Touch Default) only, then add Level 2 (Simple Override) and Level 3 (Full Customization) based on user feedback and proven needs.

## Rationale

**Phased Implementation Strategy:**
- **Phase 1:** Build bulletproof Level 1 experience first - single default profile that works for everyone
- **Phase 2:** Add Level 2 based on actual user requests, not assumptions
- **Phase 3:** Enable Level 3 for proven power user needs

**Tier Definitions:**
- Level 1: Zero-config works for 80% of users - full media stack, auto-configured
- Level 2: Simple overrides for basic customization - hostname, profile selection, storage layout  
- Level 3: Full NixOS customization for power users - complete module control

**Benefits of Phased Approach:**
- Faster initial delivery with proven core experience
- User feedback drives feature development rather than guesswork
- Modular NixOS architecture enables adding options without breaking existing deployments
- Focus on reliability over features initially

## Consequences

**Positive:**
- Faster time to market with working product
- User feedback drives actual feature needs rather than assumptions
- Proven core experience before adding complexity
- Maintains simplicity for majority of users
- Modular architecture supports future expansion without breaking changes
- Focus on reliability first, features second

**Negative:**
- Initial users cannot access advanced customization (by design)
- Eventually more complex codebase with multiple UX patterns
- Future documentation overhead for multiple tiers
- Risk of over-engineering if user needs are misunderstood

**Neutral:**
- Initial focus on single-profile deployment simplifies early development
- Future tiers will be added based on proven demand, not speculation
- Architecture decisions favor simplicity first, customization second
- Implementation timeline extends over multiple phases rather than big-bang approach
