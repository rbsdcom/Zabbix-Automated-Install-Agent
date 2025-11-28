#!/usr/bin/env bash
# Auto-Install-ZabbixAgent2-Linux.sh
# Cross-distro installer for Zabbix Agent 2 (7.0.x)
# - Detects distro
# - Removes old zabbix-agent / zabbix-agent2
# - Installs official Zabbix repo for distro
# - Installs zabbix-agent2
# - Configures Server / ServerActive / Hostname / HostMetadata
# - Enables and starts service
#
# Default HostMetadata: LINUX
# Usage: sudo ./Auto-Install-ZabbixAgent2-Linux.sh <ZBX_SERVER> [ZBX_VERSION]
# Example: sudo ./Auto-Install-ZabbixAgent2-Linux.sh zabbix.example.com 7.0.21

set -euo pipefail
IFS=$'\n\t'

# -----------------------
# Parameters / Defaults
# -----------------------
if [ $# -lt 1 ]; then
  echo "Usage: $0 <ZBX_SERVER> [ZBX_VERSION]"
  exit 2
fi

ZBX_SERVER="$1"
ZBX_VERSION="${2:-7.0.21}"   # default if not provided
HOST_METADATA="${HOST_METADATA:-LINUX}"
ZBX_BRANCH="7.0"

LOGFILE="/var/log/zabbix_auto_installer.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Zabbix Agent2 Auto Installer ==="
echo "Server: $ZBX_SERVER"
echo "Version: $ZBX_VERSION (branch: $ZBX_BRANCH)"
echo "HostMetadata: $HOST_METADATA"
echo "Log: $LOGFILE"
echo ""

# -----------------------
# Sanity checks
# -----------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Run this script as root (sudo)."
  exit 3
fi

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID=${ID,,}          # normalize lowercase
  OS_VER=${VERSION_ID}
else
  echo "❌ /etc/os-release not found. Cannot detect distro."
  exit 4
fi

echo "Detected OS: $OS_ID $OS_VER"

# -----------------------
# Helpers
# -----------------------
run_cmd() {
  echo "+ $*"
  "$@"
}

# -----------------------
# Remove old Zabbix agent(s)
# -----------------------
remove_old_zabbix() {
  echo ""
  echo "➡ Removing any old Zabbix installations..."

  # Stop services if exist
  systemctl stop zabbix-agent zabbix-agent2 2>/dev/null || true

  if command -v apt >/dev/null 2>&1; then
    apt-get remove -y zabbix-agent zabbix-agent2 zabbix-release || true
    apt-get purge -y zabbix-agent zabbix-agent2 || true
    rm -f /etc/apt/sources.list.d/zabbix.list /tmp/zabbix-release.deb || true
    apt-get autoremove -y || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf remove -y zabbix-agent zabbix-agent2 zabbix-release || true
  elif command -v yum >/dev/null 2>&1; then
    yum remove -y zabbix-agent zabbix-agent2 zabbix-release || true
  elif command -v zypper >/dev/null 2>&1; then
    zypper remove -y zabbix-agent zabbix-agent2 zabbix-release || true
  else
    echo "⚠ No known package manager to remove packages. Attempting filesystem cleanup..."
  fi

  rm -rf /etc/zabbix /var/log/zabbix /var/run/zabbix /var/lib/zabbix || true

  echo "✔ Old Zabbix artifacts removed (if any)."
}

# -----------------------
# Install repo & agent
# -----------------------
install_repo_and_agent() {
  echo ""
  echo "➡ Installing Zabbix repo and agent for $OS_ID $OS_VER..."

  case "$OS_ID" in
    ubuntu|debian)
      # Map ubuntu version for repo filename (use generic 22.04 file if not exact available)
      UB_REL=$(lsb_release -rs 2>/dev/null || echo "$OS_VER")
      # Use the generic zabbix-release package for the branch (works across minor versions)
      REPO_DEB="/tmp/zabbix-release_${ZBX_BRANCH}-6+ubuntu${UB_REL}_all.deb"
      REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_BRANCH}/ubuntu/pool/main/z/zabbix-release/$(basename $REPO_DEB)"
      echo "Downloading $REPO_URL"
      if ! curl -fsSL -o "$REPO_DEB" "$REPO_URL"; then
        # fallback to ubuntu22.04 package
        REPO_DEB="/tmp/zabbix-release_${ZBX_BRANCH}-6+ubuntu22.04_all.deb"
        REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_BRANCH}/ubuntu/pool/main/z/zabbix-release/$(basename $REPO_DEB)"
        echo "Fallback to $REPO_URL"
        curl -fsSL -o "$REPO_DEB" "$REPO_URL"
      fi
      dpkg -i "$REPO_DEB" || apt-get -f install -y
      apt-get update -y
      apt-get install -y zabbix-agent2
      ;;

    rhel|centos|rocky|almalinux)
      # For RHEL family, use major version number
      MAJOR_VER="${OS_VER%%.*}"
      RPM_URL="https://repo.zabbix.com/zabbix/${ZBX_BRANCH}/rhel/${MAJOR_VER}/x86_64/zabbix-release-${ZBX_BRANCH}-6.el${MAJOR_VER}.noarch.rpm"
      echo "Downloading $RPM_URL"
      curl -fsSL -o /tmp/zabbix-release.rpm "$RPM_URL" || { echo "❌ Failed to download repo RPM"; exit 10; }
      rpm -Uvh /tmp/zabbix-release.rpm
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y zabbix-agent2
      else
        yum install -y zabbix-agent2
      fi
      ;;

    amzn)
      # Amazon Linux 2 -> use RHEL8 packages
      RPM_URL="https://repo.zabbix.com/zabbix/${ZBX_BRANCH}/rhel/8/x86_64/zabbix-release-${ZBX_BRANCH}-6.el8.noarch.rpm"
      echo "Downloading $RPM_URL"
      curl -fsSL -o /tmp/zabbix-release.rpm "$RPM_URL"
      rpm -Uvh /tmp/zabbix-release.rpm
      yum install -y zabbix-agent2
      ;;

    sles|opensuse*|suse)
      MAJOR_VER="${OS_VER%%.*}"
      RPM_URL="https://repo.zabbix.com/zabbix/${ZBX_BRANCH}/sles/${MAJOR_VER}/x86_64/zabbix-release-${ZBX_BRANCH}-6.sles${MAJOR_VER}.noarch.rpm"
      echo "Downloading $RPM_URL"
      curl -fsSL -o /tmp/zabbix-release.rpm "$RPM_URL"
      rpm -Uvh /tmp/zabbix-release.rpm
      zypper refresh
      zypper install -y zabbix-agent2
      ;;

    *)
      echo "❌ Unsupported OS: $OS_ID"
      exit 11
      ;;
  esac

  echo "✔ Repo and package installation attempted."
}

# -----------------------
# Configure agent (safe: insert or update)
# -----------------------
configure_agent() {
  CONF="/etc/zabbix/zabbix_agent2.conf"
  if [ ! -f "$CONF" ]; then
    echo "❌ Config file not found: $CONF"
    exit 12
  fi

  echo ""
  echo "➡ Configuring $CONF"

  # Backup
  cp -a "$CONF" "${CONF}.orig-$(date +%s)" || true

  # Ensure Server
  if grep -qE "^Server=" "$CONF"; then
    sed -i "s#^Server=.*#Server=${ZBX_SERVER}#g" "$CONF"
  else
    echo "Server=${ZBX_SERVER}" >> "$CONF"
  fi

  # Ensure ServerActive
  if grep -qE "^ServerActive=" "$CONF"; then
    sed -i "s#^ServerActive=.*#ServerActive=${ZBX_SERVER}#g" "$CONF"
  else
    echo "ServerActive=${ZBX_SERVER}" >> "$CONF"
  fi

  # Hostname
  MYHOST="$(hostname)"
  if grep -qE "^Hostname=" "$CONF"; then
    sed -i "s#^Hostname=.*#Hostname=${MYHOST}#g" "$CONF"
  else
    echo "Hostname=${MYHOST}" >> "$CONF"
  fi

  # HostMetadata (insert if not present)
  if grep -qE "^HostMetadata=" "$CONF"; then
    sed -i "s#^HostMetadata=.*#HostMetadata=${HOST_METADATA}#g" "$CONF"
  else
    echo "HostMetadata=${HOST_METADATA}" >> "$CONF"
  fi

  # Optionally enable HostMetadataItem? (leave commented)

  # Ensure permissions
  chmod 644 "$CONF" || true

  echo "✔ Configuration applied."
}

# -----------------------
# Start and validate service
# -----------------------
start_and_validate() {
  echo ""
  echo "➡ Enabling and starting zabbix-agent2 service..."
  systemctl daemon-reload || true
  systemctl enable --now zabbix-agent2 || true

  sleep 2
  if systemctl is-active --quiet zabbix-agent2; then
    echo "✅ zabbix-agent2 is active."
  else
    echo "❌ zabbix-agent2 failed to start. See: journalctl -u zabbix-agent2 -xe"
    exit 20
  fi
}

# -----------------------
# RUN
# -----------------------
remove_old_zabbix
install_repo_and_agent
configure_agent
start_and_validate

echo ""
echo "🎉 Installation finished successfully."
echo "Hostname: $(hostname)"
echo "HostMetadata: ${HOST_METADATA}"
echo "Zabbix Server: ${ZBX_SERVER}"
echo "Log: ${LOGFILE}"
exit 0
