#!/bin/bash

ZBX_SERVER="186.233.102.2"
HOST_METADATA="LINUX"
AGENT_VERSION="7.0"

# Detecta distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        echo "❌ Não foi possível detectar o sistema operacional."
        exit 1
    fi
}

# Remove qualquer versão anterior (agent ou agent2)
remove_old_agents() {
    echo "🧹 Removendo versões antigas do Zabbix..."

    case "$DISTRO" in
        ubuntu|debian)
            sudo apt remove -y zabbix-agent zabbix-agent2 2>/dev/null
            ;;
        centos|rhel|almalinux|rocky)
            sudo yum remove -y zabbix-agent zabbix-agent2 2>/dev/null
            ;;
    esac
}

# Adiciona repositório correto
add_repo() {
    echo "📦 Adicionando repositório da Zabbix..."

    case "$DISTRO" in
        ubuntu|debian)
            wget https://repo.zabbix.com/zabbix/${AGENT_VERSION}/${DISTRO}/pool/main/z/zabbix-release/zabbix-release_${AGENT_VERSION}-3+${DISTRO}${VERSION}_all.deb
            sudo dpkg -i zabbix-release_${AGENT_VERSION}-3+${DISTRO}${VERSION}_all.deb
            sudo apt update
            ;;
        centos|rhel|almalinux|rocky)
            sudo rpm -Uvh https://repo.zabbix.com/zabbix/${AGENT_VERSION}/rhel/${VERSION}/x86_64/zabbix-release-${AGENT_VERSION}-1.el${VERSION}.noarch.rpm
            sudo yum clean all
            ;;
        *)
            echo "❌ Distro não suportada automaticamente: $DISTRO"
            exit 1
            ;;
    esac
}

# Instala o agent2
install_agent() {
    echo "📥 Instalando Zabbix Agent 2..."

    case "$DISTRO" in
        ubuntu|debian)
            sudo apt install -y zabbix-agent2
            ;;
        centos|rhel|almalinux|rocky)
            sudo yum install -y zabbix-agent2
            ;;
    esac
}

# Configura agent2
configure_agent() {
    CONF="/etc/zabbix/zabbix_agent2.conf"

    echo "⚙️ Configurando Agent..."
    
    sudo sed -i "s/^Server=.*/Server=$ZBX_SERVER/" $CONF
    sudo sed -i "s/^ServerActive=.*/ServerActive=$ZBX_SERVER/" $CONF
    sudo sed -i "s/^# HostMetadata=.*/HostMetadata=$HOST_METADATA/" $CONF
}

# Inicia serviço
start_agent() {
    echo "🚀 Iniciando serviço do agent..."
    sudo systemctl enable zabbix-agent2
    sudo systemctl restart zabbix-agent2

    echo "🌟 Status:"
    sudo systemctl status zabbix-agent2 --no-pager
}

### EXECUÇÃO ###

detect_distro
remove_old_agents
add_repo
install_agent
configure_agent
start_agent

echo ""
echo "✅ Instalado com sucesso!"
echo "Server: $ZBX_SERVER"
echo "Metadata: $HOST_METADATA"
