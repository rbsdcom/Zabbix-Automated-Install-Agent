#!/bin/bash

ZBX_SERVER="186.233.102.2"
HOST_METADATA="LINUX"
ZBX_VERSION="7.0"

# Detecta versão real do Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)

if [[ "$UBUNTU_VERSION" == "22.04" ]]; then
    REPO_PKG="zabbix-release_${ZBX_VERSION}-3+ubuntu22.04_all.deb"
elif [[ "$UBUNTU_VERSION" == "20.04" ]]; then
    REPO_PKG="zabbix-release_${ZBX_VERSION}-3+ubuntu20.04_all.deb"
elif [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    REPO_PKG="zabbix-release_${ZBX_VERSION}-3+ubuntu24.04_all.deb"
else
    echo "❌ Ubuntu version $UBUNTU_VERSION not supported automatically."
    exit 1
fi

REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_VERSION}/ubuntu/pool/main/z/zabbix-release/${REPO_PKG}"

echo "=== Installing Zabbix Repository ==="
echo "Ubuntu detected: $UBUNTU_VERSION"
echo "Downloading: $REPO_URL"

wget $REPO_URL -O $REPO_PKG
sudo dpkg -i $REPO_PKG
sudo apt update

echo "=== Removing previous Zabbix Agents ==="
sudo apt remove -y zabbix-agent zabbix-agent2 || true

echo "=== Installing Zabbix Agent 2 ==="
sudo apt install -y zabbix-agent2

echo "=== Configuring Zabbix Agent 2 ==="
CONF="/etc/zabbix/zabbix_agent2.conf"

sudo sed -i "s/^Server=.*/Server=$ZBX_SERVER/" $CONF
sudo sed -i "s/^ServerActive=.*/ServerActive=$ZBX_SERVER/" $CONF

# Se não existir HostMetadata, adiciona
if grep -q "^HostMetadata=" "$CONF"; then
    sudo sed -i "s/^HostMetadata=.*/HostMetadata=$HOST_METADATA/" $CONF
else
    echo "HostMetadata=$HOST_METADATA" | sudo tee -a $CONF > /dev/null
fi

echo "=== Starting Agent ==="
sudo systemctl enable zabbix-agent2
sudo systemctl restart zabbix-agent2

echo "=== Done! ==="
systemctl status zabbix-agent2 --no-pager

echo ""
echo "🎉 Installation completed!"
echo "Server: $ZBX_SERVER"
echo "HostMetadata: $HOST_METADATA"
