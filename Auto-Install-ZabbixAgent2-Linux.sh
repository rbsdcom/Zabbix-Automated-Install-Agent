#!/bin/bash

# ============================
#  CONFIGURATION
# ============================
ZBX_SERVER="186.233.102.2"
HOST_METADATA="PROD_LINUX"


# ============================
#  OS DETECTION
# ============================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VER=$VERSION_ID
else
    echo "❌ Unable to detect OS. /etc/os-release is missing."
    exit 1
fi

echo "➡️ Detected OS: $OS_ID $OS_VER"

# ============================
# INSTALLATION
# ============================

install_zabbix_repo() {
    case "$OS_ID" in
        ubuntu|debian)
            wget https://repo.zabbix.com/zabbix/7.0/$OS_ID/pool/main/z/zabbix-release/zabbix-release_7.0-2+$OS_ID${OS_VER}_all.deb
            sudo dpkg -i zabbix-release_7.0-2+$OS_ID${OS_VER}_all.deb
            sudo apt update
        ;;
        rhel|centos|rocky|almalinux)
            sudo rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/$OS_VER/x86_64/zabbix-release-7.0-2.el$OS_VER.noarch.rpm
        ;;
        amzn)
            sudo rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/8/x86_64/zabbix-release-7.0-2.el8.noarch.rpm
        ;;
        sles|opensuse*)
            sudo rpm -Uvh https://repo.zabbix.com/zabbix/7.0/sles/$OS_VER/x86_64/zabbix-release-7.0-2.sles$OS_VER.noarch.rpm
        ;;
        *)
            echo "❌ Unsupported OS: $OS_ID"
            exit 1
        ;;
    esac
}

install_agent() {
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y zabbix-agent2
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y zabbix-agent2
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zabbix-agent2
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y zabbix-agent2
    else
        echo "❌ No compatible package manager found."
        exit 1
    fi
}

# ============================
#  CONFIGURATION
# ============================

configure_agent() {
    CONF="/etc/zabbix/zabbix_agent2.conf"

    sudo sed -i "s/^Server=.*/Server=$ZBX_SERVER/" $CONF
    sudo sed -i "s/^ServerActive=.*/ServerActive=$ZBX_SERVER:$ZBX_SERVER_PORT/" $CONF
    sudo sed -i "s/^Hostname=.*/Hostname=$(hostname)/" $CONF
     sudo sed -i "s/^HostMetadata=.*/HostMetadata=$HOST_METADATA/" $CONF

}


# ============================
#  RUN STEPS
# ============================

echo "➡️ Installing Zabbix repository..."
install_zabbix_repo

echo "➡️ Installing Zabbix Agent..."
install_agent

echo "➡️ Configuring Zabbix Agent..."
configure_agent

echo "✅ Installation complete!"
echo "HostMetadata = $HOST_METADATA"
echo "ServerActive = $ZBX_SERVER:$ZBX_SERVER_PORT"
