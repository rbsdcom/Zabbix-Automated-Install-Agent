#!/bin/bash

set -e

ZABBIX_SERVER="186.233.102.2"
HOST_METADATA="LINUX"

echo "=== Detecting Linux distribution ==="

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    echo "Unable to detect OS."
    exit 1
fi

echo "Detected: $DISTRO $VERSION"

###############################################
# 1. REMOVE OLD AGENTS (zabbix-agent e agent2)
###############################################

echo "=== Removing previous Zabbix versions ==="

if command -v systemctl >/dev/null 2>&1; then
    systemctl stop zabbix-agent 2>/dev/null || true
    systemctl stop zabbix-agent2 2>/dev/null || true
fi

if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
    apt remove -y zabbix-agent zabbix-agent2 2>/dev/null || true
elif [ "$DISTRO" = "centos" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "rocky" ] || [ "$DISTRO" = "almalinux" ]; then
    yum remove -y zabbix-agent zabbix-agent2 2>/dev/null || true
fi

###############################################
# 2. INSTALL REPO — AUTO-DETECT CORRECT .DEB
###############################################

echo "=== Installing Zabbix Repository ==="

if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
    BASE_URL="https://repo.zabbix.com/zabbix/7.0/$DISTRO/pool/main/z/zabbix-release/"

    echo "Fetching available zabbix-release files..."

    # Lista todos os pacotes disponíveis e pega o que combina com a versão
    RELEASE_FILE=$(curl -s $BASE_URL | grep -o "zabbix-release_7.0-[0-9]\++$DISTRO$VERSION\(_\|\.\)all\.deb" | head -n 1)

    if [ -z "$RELEASE_FILE" ]; then
        echo "ERROR: No matching zabbix-release package found for $DISTRO $VERSION"
        exit 1
    fi

    DOWNLOAD_URL="${BASE_URL}${RELEASE_FILE}"

    echo "Downloading: $DOWNLOAD_URL"
    curl -s -o /tmp/zabbix-release.deb "$DOWNLOAD_URL"

    dpkg -i /tmp/zabbix-release.deb
    apt update -y

elif [ "$DISTRO" = "centos" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "rocky" ] || [ "$DISTRO" = "almalinux" ]; then
    rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/zabbix-release-7.0-4.el7.noarch.rpm
    yum clean all
else
    echo "Unsupported distribution."
    exit 1
fi

###############################################
# 3. INSTALL Zabbix Agent2
###############################################

echo "=== Installing Zabbix Agent 2 ==="

if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
    apt install -y zabbix-agent2
else
    yum install -y zabbix-agent2
fi

###############################################
# 4. CONFIGURE AGENT2 WITH METADATA
###############################################

echo "=== Configuring Zabbix Agent 2 ==="

CONF="/etc/zabbix/zabbix_agent2.conf"

sed -i "s/^Server=.*/Server=$ZABBIX_SERVER/" $CONF
sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER/" $CONF

if grep -q "^HostMetadata=" "$CONF"; then
    sed -i "s/^HostMetadata=.*/HostMetadata=$HOST_METADATA/" $CONF
else
    echo "HostMetadata=$HOST_METADATA" >> $CONF
fi

###############################################
# 5. START SERVICE
###############################################

echo "=== Starting Zabbix Agent 2 ==="
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2

echo "=== Zabbix Agent 2 Installed and Running ==="
systemctl status zabbix-agent2 --no-pager
