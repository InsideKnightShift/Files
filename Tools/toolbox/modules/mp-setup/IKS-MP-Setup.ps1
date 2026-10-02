# =====================================================================
#   InsideEARTH - KnightShift Multiplayer Setup v1.0
# =====================================================================

# ---------------------------------------------------------------------
#  ** UNVERIFIED PLACEHOLDER DATA **
#  This game's GitHub repo, VPN/community server address, subnet and
#  level-repository were GUESSED from the Earth 2150 naming pattern -
#  they do not point at anything real yet. Confirm/replace before use:
#    GitHub repo : InsideKnightShift/Files
#    VPN server  : vpnnetserverks.insideearth.info
#    Subnet      : 10.21.90.0/24
#    Levels repo : InsideKnightShift/Levels
# ---------------------------------------------------------------------

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Self-elevation check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

Clear-Host

$host.ui.RawUI.WindowTitle = "InsideEARTH - KnightShift Multiplayer Setup"

# Variable Definitions
$Name            = 'InsideEARTH KnightShift Community Server'
$ServerHost      = 'vpnnetserverks.insideearth.info'
$ValueName       = 'AddressIP'
$IEPort          = 17141
$TWPort          = 17104
$InstallOpenVPN  = $true
$Repo            = 'InsideKnightShift/Files'
$Ref             = 'refs/heads/main'
$Subnet          = '10.21.90.0/24'
$SubnetAliases   = @($Subnet, ($Subnet -replace '/24', '/255.255.255.0'))

# Construct the formatted registry string for IP checking
$addressIpFormatted = '"EarthNet""netserver.earthnet.de""InsideEARTH""vpnnetserverks.insideearth.info:17141"'

# Display Banner First
Write-Host
Write-Host " ===================================================" -ForegroundColor Green
Write-Host "   InsideEARTH - KnightShift Multiplayer Setup v1.0" -ForegroundColor Green
Write-Host " ===================================================" -ForegroundColor Green
Write-Host



# ---------- 1/3) OpenVPN Installation & Profile Setup -----------------
Write-Host
Write-Host " [1/3] OpenVPN Setup..." -ForegroundColor Cyan
if ($InstallOpenVPN) {
    try {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host " - winget is not detected. Silently installing winget..." -ForegroundColor Yellow

            $oldProgress = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'

            $tempDir = Join-Path $env:TEMP "WingetInstaller"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                $vcLibsPath = Join-Path $tempDir 'VCLibs.appx'
                $uiXamlPath = Join-Path $tempDir 'UIXaml.appx'
                $wingetPath = Join-Path $tempDir 'Winget.msixbundle'

                Invoke-WebRequest -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $vcLibsPath -UseBasicParsing
                Invoke-WebRequest -Uri 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx' -OutFile $uiXamlPath -UseBasicParsing
                Invoke-WebRequest -Uri 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle' -OutFile $wingetPath -UseBasicParsing

                Add-AppxPackage -Path $vcLibsPath -ErrorAction SilentlyContinue
                Add-AppxPackage -Path $uiXamlPath -ErrorAction SilentlyContinue
                Add-AppxPackage -Path $wingetPath -ErrorAction Stop

                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                Write-Host " - winget installed successfully." -ForegroundColor Green
            } finally {
                $ProgressPreference = $oldProgress
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        $isInstalled = winget list --id OpenVPNTechnologies.OpenVPNConnect --exact 2>$null | Out-String

        if ($isInstalled -match 'OpenVPNConnect') {
            Write-Host " - OpenVPN Connect is already installed. Stopping running instances..." -ForegroundColor Yellow
            Stop-Process -Name "openvpnconnect", "openvpn" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        } else {
            Write-Host " - Installing OpenVPN Connect silently via winget..." -ForegroundColor Yellow
            winget install OpenVPNTechnologies.OpenVPNConnect --accept-source-agreements --accept-package-agreements --silent | Out-Null
            Write-Host " - OpenVPN installation completed." -ForegroundColor Green
        }

        $ovpnUrl  = "https://raw.githubusercontent.com/$Repo/$Ref/EarthNet/IKS-KS-VPN-TCP.ovpn"
        $ovpnPath = Join-Path $env:TEMP 'IKS-KS-VPN-TCP.ovpn'

        Write-Host " - Downloading OpenVPN profile configuration..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $ovpnUrl -OutFile $ovpnPath -UseBasicParsing

        $ovpnCli = "${env:ProgramFiles}\OpenVPN Connect\openvpnconnect.exe"
        if (Test-Path $ovpnCli) {
            Write-Host " - Checking and updating profile in OpenVPN Connect..." -ForegroundColor Yellow

            $profileListJson = & "$ovpnCli" --list-profiles 2>$null | Out-String
            if ($profileListJson -match '"id":\s*"([^"]+)"') {
                $existingId = $matches[1]
                cmd.exe /c "`"$ovpnCli`" --remove-profile=$existingId >nul 2>&1"
            }

            cmd.exe /c "`"$ovpnCli`" --import-profile=`"$ovpnPath`" >nul 2>&1"

            Write-Host " - OpenVPN profile imported successfully." -ForegroundColor Green
        } else {
            Write-Host " - Profile downloaded to: $ovpnPath (Import manually in OpenVPN Connect)." -ForegroundColor Yellow
        }
    } catch {
        Write-Host " ! OpenVPN setup failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host " - Skipped OpenVPN setup per selection." -ForegroundColor DarkGray
}

# ---------- 2/3) Check & Update Registry Configurations -----------------
Write-Host
Write-Host " [2/3] Checking registry configurations..." -ForegroundColor Cyan

$keyPath = 'HKCU:\Software\Reality Pump\KnightShift\BaseGame\Network\EarthNet'
$needsRegUpdate = $true
if (Test-Path $keyPath) {
    $currentVal = (Get-ItemProperty -Path $keyPath -Name 'AddressIP' -ErrorAction SilentlyContinue).AddressIP
    $currentPort = (Get-ItemProperty -Path $keyPath -Name 'Port' -ErrorAction SilentlyContinue).Port
    if ($currentVal -eq $addressIpFormatted -and $currentPort -eq 17121) { $needsRegUpdate = $false }
}

if (-not $needsRegUpdate) {
    Write-Host " - Registry entry is already configured correctly. Skipping update." -ForegroundColor DarkGray
} else {
    Write-Host " - Backing up registry key..." -ForegroundColor Yellow
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $backupBase = 'HKCU:\Software\Reality Pump\KnightShift'
    if (Test-Path $backupBase) {
        $backupFile = Join-Path $desktopPath "IKS-Backup-$timestamp.reg"
        $winRegPath = $backupBase -replace 'HKCU:\\', 'HKEY_CURRENT_USER\'
        Start-Process reg.exe -ArgumentList "export `"$winRegPath`" `"$backupFile`" /y" -NoNewWindow -Wait
        Write-Host " - Exported backup to: $backupFile" -ForegroundColor DarkGray
    }

    try {
        if (-not (Test-Path $keyPath)) { New-Item -Path $keyPath -Force | Out-Null }
        Set-ItemProperty -Path $keyPath -Name 'AddressIP' -Value $addressIpFormatted -Type String
        Set-ItemProperty -Path $keyPath -Name 'Port' -Value 17121 -Type DWord
        Write-Host " - Updated registry entries successfully." -ForegroundColor Green
    } catch {
        Write-Host " ! Registry update failed: $_" -ForegroundColor Red
    }
}

# ---------- 3/3) Configure Firewall Rules ------------------------------
Write-Host
Write-Host " [3/3] Configuring Windows Firewall Rules..." -ForegroundColor Cyan

$fwRules = @(
    @{ Name = 'IKS - Game Port (TCP 17121)'; Protocol = 'TCP'; LocalPort = '17121'; RemoteAddress = $Subnet },
    @{ Name = 'IKS - Game Port (UDP 17121)'; Protocol = 'UDP'; LocalPort = '17121'; RemoteAddress = $Subnet },
    @{ Name = 'IKS - ICMPv4 Allow Subnet';        Protocol = 'ICMPv4'; RemoteAddress = $Subnet }
)

function Set-IKSFirewallRules {
    param($rules)
    foreach ($r in $rules) {
        Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

        $params = @{
            DisplayName   = $r.Name
            Direction     = 'Inbound'
            Action        = 'Allow'
            Protocol      = $r.Protocol
            Profile       = 'Any'
            RemoteAddress = $r.RemoteAddress
        }
        if ($r.LocalPort) { $params['LocalPort'] = $r.LocalPort }

        New-NetFirewallRule @params | Out-Null
    }
}

$needsFwUpdate = $false
foreach ($r in $fwRules) {
    $existingRule = Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
    if (-not $existingRule -or (@($existingRule | Where-Object { $_.Enabled -ne 'True' }).Count -gt 0)) {
        $needsFwUpdate = $true
        break
    }

    $existingScope = @($existingRule | Get-NetFirewallAddressFilter)[0]
    $existingAddr  = @($existingScope.RemoteAddress)[0]
    if ($SubnetAliases -notcontains $existingAddr) {
        $needsFwUpdate = $true
        break
    }
}

if (-not $needsFwUpdate) {
    Write-Host " - All firewall rules and subnet scopes are already configured correctly. Skipping." -ForegroundColor DarkGray
} else {
    try {
        Set-IKSFirewallRules -rules $fwRules
        Write-Host " - Firewall rules and subnet scope applied successfully." -ForegroundColor Green
    } catch {
        Write-Host " ! Firewall setup failed: $_" -ForegroundColor Red
    }
}

# ---------- Complete -------------------------------------------------
Write-Host
Write-Host " ===================================================" -ForegroundColor Green
Write-Host "   Setup complete. Launch KnightShift and Enjoy!" -ForegroundColor Green
Write-Host " ===================================================" -ForegroundColor Green
Write-Host

Read-Host "Press Enter to exit..."
