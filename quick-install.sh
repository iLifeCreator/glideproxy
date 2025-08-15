#!/bin/bash

# Quick Install Script for Enhanced Proxy Server v2.0
# One-liner installer for TimeWeb VPS
# Usage: curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/quick-install.sh | sudo bash

set -e

echo "🚀 Enhanced Proxy Server v2.0 - Quick Install"
echo "============================================"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   echo "Use: curl -sSL ... | sudo bash"
   exit 1
fi

# Quick system check
echo "✓ Checking system..."
apt-get update -qq

# Create working directory
echo "✓ Creating working directory..."
mkdir -p /opt/proxy-installer
cd /opt/proxy-installer

# Download and run TimeWeb deploy script
echo "✓ Downloading installer..."
curl -sSL -o timeweb-deploy.sh \
    https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/timeweb-deploy.sh

if [ -f timeweb-deploy.sh ]; then
    chmod +x timeweb-deploy.sh
    echo "✓ Starting interactive installation..."
    echo
    ./timeweb-deploy.sh
else
    echo "❌ Failed to download installer"
    exit 1
fi