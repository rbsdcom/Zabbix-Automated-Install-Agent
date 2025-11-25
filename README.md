# Zabbix Agent 2 – Automated Windows Installer (PowerShell)

This repository contains a fully automated PowerShell script for installing **Zabbix Agent 2** on Windows systems.  
The goal is to simplify deployment in distributed or multi-client environments, especially when using **Auto-Registration** with Active Agent Mode.

---

## 🚀 Features

- Automatic elevation to Administrator  
- Full cleanup of previous Zabbix Agent installations  
- Directory recreation for a clean setup  
- Direct download of the MSI from the official Zabbix CDN  
- Automatic configuration with:
  - `Server`
  - `ServerActive`
  - `Hostname` (prefixed with `CLI-`)
  - `HostMetadata`  
- Log-enabled silent installation  
- Service validation and automatic start  
- Animated ASCII logo (optional, just for fun 😄)

---

## 📌 Usage

1. Clone or download this repository.  
2. Edit the variables inside the script to match your environment:

```powershell
$zabbixServer  = "IP_SERVER"
$hostmetadata  = "WINDOWS"
$version       = "7.0.21"


Run the script:
powershell.exe -ExecutionPolicy Bypass -File .\install_zabbix_agent2.ps1
