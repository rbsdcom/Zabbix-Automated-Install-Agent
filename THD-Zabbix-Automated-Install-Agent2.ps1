# Verifica e solicita elevação de administrador
param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    if ($elevated) {
        throw "Falha na elevação de privilégios"
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -Elevated" -f $MyInvocation.MyCommand.Path)
        exit
    }
}

# Caminho e URL - Versão melhorada
function Show-TOHOSTLogo {
    $logo = @"
    ████████╗ ██████╗    ██╗  ██╗ ██████╗ ███████╗████████╗
    ╚══██╔══╝██╔═══██╗   ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
       ██║   ██║   ██║   ██║████║██║   ██║███████╗   ██║   
       ██║   ██║   ██║   ██║  ██║██║   ██║╚════██║   ██║   
       ██║   ╚██████╔╝   ██║  ██║ ██████╔╝███████║   ██║   
       ╚═╝    ╚═════╝    ╚══════╝ ╚═════╝ ╚══════╝   ╚═╝   
                                                                 
    ██████╗  █████╗ ████████╗ █████╗     ██████╗███████╗███╗   ██╗████████╗███████╗██████╗ 
    ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗   ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██╔════╝██╔══██╗
    ██║  ██║███████║   ██║   ███████║   ██║     █████╗  ██╔██╗ ██║   ██║   █████╗  ██████╔╝
    ██║  ██║██╔══██║   ██║   ██╔══██║   ██║     ██╔══╝  ██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗
    ██████╔╝██║  ██║   ██║   ██║  ██║   ╚██████╗███████╗██║ ╚████║   ██║   ███████╗██║  ██║
    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝    ╚═════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
"@
    $lines = $logo -split "`n"
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor Green
        Start-Sleep -Milliseconds 120
    }
}

Show-TOHOSTLogo

# Configurações
$installDir = "C:\Program Files\Zabbix Agent 2"
$version = "7.0.21"
$installerName = "zabbix_agent2-$version-windows-amd64-openssl.msi"
$installerPath = "$installDir\$installerName"
$url = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/$version/$installerName"
$zabbixServer = "IP_SERVER"
$hostmetadata = "WINDOWS"

Write-Host "=== Zabbix Agent 2 - Instalação Automática ===" -ForegroundColor Cyan
Write-Host "Versão: $version" -ForegroundColor Yellow
Write-Host "Servidor: $zabbixServer" -ForegroundColor Yellow
Write-Host "Executando como Administrador: SIM" -ForegroundColor Green
Write-Host ""

try {
    # 1️⃣ Verifica se já existe uma versão instalada
    Write-Host "[1/5] Verificando instalações anteriores..." -ForegroundColor Green
    $installed = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Zabbix Agent*" }

    if ($installed) {
        Write-Host "   Versão existente encontrada: $($installed.Name)" -ForegroundColor Yellow
        Write-Host "   Desinstalando versão anterior..." -ForegroundColor Yellow
        foreach ($app in $installed) {
            Write-Host "   Desinstalando: $($app.Name)"
            & msiexec.exe /x $app.IdentifyingNumber /qn /norestart
        }
        Start-Sleep -Seconds 5
    } else {
        Write-Host "   Nenhuma instalação anterior encontrada." -ForegroundColor Green
    }

    # 2️⃣ Remove o diretório antigo se existir
    Write-Host "[2/5] Limpando diretório de instalação..." -ForegroundColor Green
    if (Test-Path $installDir) {
        Write-Host "   Removendo diretório antigo: $installDir"
        Remove-Item -Path $installDir -Recurse -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    }

    # 3️⃣ Cria o diretório novamente
    Write-Host "[3/5] Criando diretório de instalação..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Host "   Diretório criado: $installDir" -ForegroundColor Green

    # 4️⃣ Baixa o novo instalador
    Write-Host "[4/5] Baixando instalador..." -ForegroundColor Green
    Write-Host "   URL: $url"
    
    # Verifica se o arquivo já existe e remove
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
    }

    # Download com progresso
    $progressPreference = $ProgressPreference
    $ProgressPreference = 'Continue'
    Invoke-WebRequest -Uri $url -OutFile $installerPath -UseBasicParsing
    $ProgressPreference = $progressPreference

    if (Test-Path $installerPath) {
        Write-Host "   ✅ Download concluído: $installerPath" -ForegroundColor Green
    } else {
        throw "Falha no download do instalador"
    }

    # 5️⃣ Instala a nova versão
    Write-Host "[5/5] Instalando Zabbix Agent 2..." -ForegroundColor Green
    $installArgs = @(
        "/i", "`"$installerPath`"",
        "/qn",
        "SERVER=$zabbixServer",
        "SERVERACTIVE=$zabbixServer",
        "HOSTNAME=CLI-$env:COMPUTERNAME",
        "HostMetadata=$hostmetadata",
        "/L*V", "`"$installDir\install.log`""
    )
    
    $process = Start-Process msiexec.exe -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Host "   ✅ Instalação concluída com sucesso!" -ForegroundColor Green
        Write-Host "   Servidor configurado: $zabbixServer" -ForegroundColor Green
        Write-Host "   Hostname: CLI-$env:COMPUTERNAME" -ForegroundColor Green
        
        # Verifica se o serviço está rodando
        $service = Get-Service -Name "Zabbix Agent 2" -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "   Status do serviço: $($service.Status)" -ForegroundColor Green
            if ($service.Status -ne "Running") {
                Write-Host "   Iniciando serviço..." -ForegroundColor Yellow
                Start-Service -Name "Zabbix Agent 2"
            }
        }
    } else {
        throw "Erro na instalação. Código de saída: $($process.ExitCode)"
    }

} catch {
    Write-Host "❌ Erro durante a instalação: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalhes: $($_.Exception.StackTrace)" -ForegroundColor Red
    
    # Mantém a janela aberta para visualizar o erro
    Write-Host "`nPressione qualquer tecla para sair..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""
Write-Host "=== Instalação finalizada com sucesso! ===" -ForegroundColor Green
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")