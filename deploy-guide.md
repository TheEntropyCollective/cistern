# Cistern Deployment Guide - Eden & Rivers

## Prerequisites

1. **Physical Server (Eden)**:
   - Server with existing OS that allows SSH access
   - Root access or sudo privileges
   - Network connectivity (static IP recommended)
   - At least 8GB RAM and 100GB storage

2. **Proxmox Server** (for VMs):
   - Proxmox VE installed and accessible
   - NixOS ISO uploaded to Proxmox storage
   - API access configured

## Step 1: Deploy Eden (Physical Server)

### Option A: If Eden has any Linux OS with SSH:
```bash
# From your local machine in the cistern directory
./scripts/provision.sh 192.168.1.50 generic
```

This will:
- Connect via SSH
- Wipe the existing OS
- Install NixOS with Cistern configuration
- Configure all media services

### Option B: If Eden needs manual NixOS installation first:
1. Boot from NixOS ISO
2. Follow standard NixOS installation
3. Enable SSH: `systemctl start sshd`
4. Set root password: `passwd`
5. Note the IP address: `ip addr`
6. From your local machine: `./scripts/provision.sh <eden-ip> generic`

## Step 2: Deploy River VMs (Terraform)

### 2.1 Prepare Proxmox
1. Upload NixOS ISO to Proxmox:
   - Download: https://nixos.org/download.html#nixos-iso
   - Upload via Proxmox web UI: Datacenter → Storage → ISO Images → Upload

2. Create API token for Terraform:
   ```bash
   # On Proxmox server
   pveum user add terraform@pve
   pveum aclmod / -user terraform@pve -role Administrator
   pveum passwd terraform@pve
   ```

### 2.2 Configure Terraform
1. Edit `terraform/terraform.tfvars`:
   - Update `proxmox_endpoint` with your Proxmox server URL
   - Update `proxmox_user` and `proxmox_password`
   - Verify `nixos_iso_path` matches your uploaded ISO

2. Initialize and deploy:
   ```bash
   cd terraform/
   terraform init
   terraform plan  # Review what will be created
   terraform apply # Create VMs
   ```

## Step 3: Verify Deployment

### Check Eden:
```bash
# SSH into Eden
ssh root@192.168.1.50

# Check services
systemctl status jellyfin
systemctl status sonarr
systemctl status radarr

# Exit SSH
exit
```

### Check River VMs:
```bash
# Terraform will output the SSH commands
terraform output ssh_commands

# Or manually:
ssh root@192.168.1.101  # Pishon
ssh root@192.168.1.102  # Gihon
```

## Step 4: Access Services

Once deployed, access your services:

### From Eden (192.168.1.50):
- **Dashboard**: http://192.168.1.50/
- **Jellyfin**: http://192.168.1.50:8096
- **Sonarr**: http://192.168.1.50:8989
- **Radarr**: http://192.168.1.50:7878
- **Prowlarr**: http://192.168.1.50:9696
- **Transmission**: http://192.168.1.50:9091
- **SABnzbd**: http://192.168.1.50:8080

### River VMs:
Currently configured as secondary nodes. Can be used for:
- Distributed storage (mount shared storage)
- Backup services
- Load balancing (configure nginx upstream)
- Monitoring (Prometheus federation)

## Step 5: Post-Deployment Configuration

### Secure Secrets Management (Recommended)

Cistern now includes encrypted secrets management using agenix. To migrate from plain text secrets:

1. **Check current secret status**:
   ```bash
   ssh eden 'sudo cistern-secrets-status'
   ```

2. **Migrate to encrypted secrets**:
   ```bash
   # SSH into the server
   ssh eden
   
   # Run the migration
   sudo /home/cistern/scripts/migrate-all-secrets.sh
   
   # Validate the migration
   sudo /home/cistern/scripts/validate-secrets.sh
   ```

3. **Commit encrypted secrets** (safe to store in git):
   ```bash
   git add secrets/*.age
   git commit -m "Add encrypted secrets"
   ```

For detailed instructions, see [Secrets Migration Guide](docs/secrets-migration-guide.md).

### Configure Services

1. **Configure Usenet** (if using):
   - Access SABnzbd: http://eden:8080
   - Add Usenet provider in Settings → Servers

2. **Add Indexers**:
   - Access Prowlarr: http://eden:9696
   - Add your preferred indexers (both torrent and Usenet)

3. **Configure Media Libraries**:
   - Access Jellyfin: http://eden:8096
   - Libraries are pre-configured but you can add more

## Ongoing Management

### Update Single Server:
```bash
./scripts/deploy.sh eden
./scripts/deploy.sh pishon
```

### Update Entire Fleet:
```bash
./scripts/deploy.sh
```

### Scale Fleet:
```bash
cd terraform/
terraform apply -var="node_count=4"  # Adds Tigris and Euphrates
```

## Troubleshooting

### Can't connect to Eden:
- Ensure firewall allows SSH (port 22)
- Check network connectivity
- Verify SSH service is running

### Terraform fails:
- Check Proxmox credentials
- Verify ISO is uploaded
- Ensure Proxmox API is accessible
- Check terraform.log for details

### Services not starting:
- Check logs: `journalctl -u jellyfin -f`
- Verify ports aren't in use: `ss -tlnp`
- Check disk space: `df -h`