---
id: task-3
title: Set up Tart VM testing environment for Cistern development
status: In Progress
assignee: []
created_date: '2025-08-25 03:46'
updated_date: '2025-08-25 04:27'
labels:
  - testing
  - virtualization
  - development
  - tart
  - apple-silicon
dependencies:
  - task-1.4
priority: high
---

## Description

Implement native macOS virtualization testing using Tart for the Cistern media server stack. Tart provides superior performance on Apple Silicon compared to traditional virtualization solutions, enabling faster iteration during development and more accurate testing of NixOS configurations before deployment to physical hardware.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Tart CLI tool is installed and configured on macOS
- [ ] NixOS VM successfully created and boots in Tart environment  
- [ ] Cistern media server configuration deploys without errors in VM
- [ ] Jellyfin web interface accessible from host macOS at expected port
- [ ] Complete testing workflow documented for ongoing development
- [ ] Performance comparison with UTM documented (bonus)
<!-- AC:END -->

## Implementation Plan

### Step 1: Decision Documentation
- Create decision document choosing Tart over UTM for VM testing
- Document rationale including native performance, CLI-first design, and NixOS support

### Step 2: Nix Darwin Integration  
- Add Tart package to `~/.config/nix/modules/apps.nix`
- Install via `sudo darwin-rebuild switch`

### Step 3: Flake Enhancement
- Integrate nixos-generators into Cistern flake
- Use DRY configuration pattern with `let...in` to avoid duplication
- Create ISO generation capability for testing

### Step 4: Configuration Structure
```nix
# Target flake.nix structure
let
  system = "x86_64-linux";
  modules = [
    ./configuration.nix
    ./modules/base.nix
    nixarr.nixosModules.default
  ];
in {
  packages.aarch64-darwin.cistern-iso = nixos-generators.nixosGenerate {
    inherit system modules;
    format = "iso";
  };
}
```

### Step 5: VM Creation and Testing
1. **Generate ISO**: Build Cistern ISO with `nix build .#cistern-iso`  
2. **Create VM**: Use `tart create cistern-test --from-iso ./result/*.iso`
3. **Test Services**: Verify Jellyfin accessibility at VM_IP:8096
4. **Document Workflow**: Create testing guide for ongoing development

### Key Commands
```bash
cd ~/.config/nix && sudo darwin-rebuild switch
cd ~/cistern && nix build .#cistern-iso
tart create cistern-test --from-iso ./result/*.iso --disk-size 20
tart run cistern-test && tart ip cistern-test
```
