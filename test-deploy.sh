#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Cistern VM Test Deployment"
echo "============================="

VM_NAME="cistern-test"

echo "📦 Step 1: Creating Ubuntu VM..."
orb create ubuntu $VM_NAME 2>/dev/null || echo "VM already exists"

echo "🔧 Step 2: Preparing VM for nixos-anywhere..."
orb -m $VM_NAME bash -c '
# Install required packages
echo "Installing required packages..."
sudo apt update -qq
sudo apt install -y openssh-server cpio

# Start SSH service
echo "Starting SSH service..."
sudo systemctl start ssh
sudo systemctl enable ssh

# Enable root login (required for nixos-anywhere)
echo "Configuring root access..."
sudo passwd -d root
sudo sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitEmptyPasswords.*/PermitEmptyPasswords yes/" /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "✅ VM prepared for nixos-anywhere"
'

echo "🌐 Step 3: Getting VM IP address..."
VM_IP=$(orb -m $VM_NAME bash -c 'hostname -I | cut -d" " -f1')
echo "VM IP: $VM_IP"

echo "🚀 Step 4: Deploying Cistern with nixos-anywhere..."
echo "This will take several minutes..."
./scripts/provision.sh $VM_IP

echo ""
echo "⏳ Step 5: Waiting for services to start..."
sleep 30

echo "🧪 Step 6: Testing Cistern deployment..."
ssh -o StrictHostKeyChecking=no root@$VM_IP bash -c '
echo "🔍 Checking systemd services..."
systemctl list-units --type=service | grep -E "(jellyfin|sonarr|radarr|sabnzbd|nginx)" || echo "Services not found yet"

echo ""
echo "🌐 Testing HTTP endpoints..."
curl -s -o /dev/null -w "Dashboard (port 80): %{http_code}\\n" http://localhost/ 2>/dev/null || echo "Dashboard: Not ready"
curl -s -o /dev/null -w "Jellyfin (port 8096): %{http_code}\\n" http://localhost:8096 2>/dev/null || echo "Jellyfin: Not ready"
curl -s -o /dev/null -w "SABnzbd (port 8080): %{http_code}\\n" http://localhost:8080 2>/dev/null || echo "SABnzbd: Not ready"

echo ""
echo "🎬 Testing emoji encoding..."
curl -s http://localhost/ 2>/dev/null | grep -o "&#127916;" >/dev/null && echo "✅ Emoji properly encoded" || echo "⚠️ Dashboard not ready or emoji issue"
' || echo "⚠️ Services still starting up"

echo ""
echo "🎉 DEPLOYMENT TEST COMPLETE!"
echo "============================"
echo "VM Name: $VM_NAME"
echo "VM IP: $VM_IP"
echo ""
echo "🔗 To access the VM:"
echo "   ssh root@$VM_IP"
echo "   orb -m $VM_NAME bash"
echo ""
echo "📱 To test services manually:"
echo "   curl http://$VM_IP/          # Dashboard"
echo "   curl http://$VM_IP:8096      # Jellyfin"
echo "   curl http://$VM_IP:8080      # SABnzbd"
echo ""
echo "🔄 To update Cistern configuration:"
echo "   ./scripts/deploy.sh $VM_NAME"
echo ""
echo "🛑 To cleanup:"
echo "   orb delete $VM_NAME"