#!/bin/bash

# ================================
# Zabbix Agent 2 Auto Installer
# Linux Version (Ubuntu/RHEL/CentOS/Rocky/Alma)
# ================================

ZBX_VERSION="7.0.21"
ZBX_SERVER="IP_SERVER"
HOST_METADATA="LINUX"
HOSTNAME="CLI-$(hostname)"

echo ""
echo "======================================"
echo "   Zabbix Agent 2 Auto Installer"
echo "   Version: $ZBX_VERSION"
echo "   Server:  $ZBX_SERVER"
echo "======================================"
echo ""

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ You must run this script as root."
    exit 1
fi

# Detect distro
if command -v apt >/dev/null 2>&1; then
    DISTRO="DEB"
elif command -v yum >/dev/null 2>&1; then
    DISTRO="RHEL"
elif command -v dnf >/dev/null 2>&1; then
    DISTRO="RHEL"
else
    echo "❌ Unsupported Linux distribution."
    exit 1
fi

echo "➡ Detected distro: $DISTRO"

# Remove old Zabbix agents
echo "➡ Checking for previous installations..."
if command -v zabbix_agentd >/dev/null 2>&1 || command -v zabbix_agent2 >/dev/null 2>&1; then
    echo "   Removing old Zabbix agent..."
    if [ "$DISTRO" == "DEB" ]; then
        apt remove -y zabbix-agent zabbix-agent2 >/dev/null 2>&1
    else
        yum remove -y zabbix-agent zabbix-agent2 >/dev/null 2>&1
    fi
else
    echo "   No old versions found."
fi

# Add Zabbix repository
echo "➡ Adding Zabbix repository..."

if [ "$DISTRO" == "DEB" ]; then
    wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZBX_VERSION}-1+ubuntu$(lsb_release -rs)_all.deb -O /tmp/zabbix-release.deb
    dpkg -i /tmp/zabbix-release.deb
    apt update -y
else
    rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/$(rpm -E %{rhel})/x86_64/zabbix-release-${ZBX_VERSION}-1.el$(rpm -E %{rhel}).noarch.rpm
    yum clean all
fi

# Install Zabbix Agent 2
echo "➡ Installing Zabbix Agent 2..."
if [ "$DISTRO" == "DEB" ]; then
    apt install -y zabbix-agent2
else
    yum install -y zabbix-agent2
fi

# Configure agent
echo "➡ Configuring Zabbix Agent 2..."

CONF="/etc/zabbix/zabbix_agent2.conf"

sed -i "s/^Server=.*/Server=$ZBX_SERVER/" $CONF
sed -i "s/^ServerActive=.*/ServerActive=$ZBX_SERVER/" $CONF
sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $CONF
sed -i "s/^# HostMetadata=.*/HostMetadata=$HOST_METADATA/" $CONF

# Enable and start agent
echo "➡ Enabling and starting service..."
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2

# Validate
sleep 2
STATUS=$(systemctl is-active zabbix-agent2)

if [ "$STATUS" == "active" ]; then
    echo ""
    echo "✅ Zabbix Agent 2 installed and running!"
    echo "   Hostname:      $HOSTNAME"
    echo "   Metadata:      $HOST_METADATA"
    echo "   Server:        $ZBX_SERVER"
else
    echo "❌ Service failed to start. Check logs:"
    echo "   journalctl -u zabbix-agent2 -xe"
fi

echo ""
echo "🎉 Installation completed."
