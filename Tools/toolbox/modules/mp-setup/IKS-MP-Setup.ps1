# =====================================================================
#   InsideKnightShift Multiplayer Setup v1.1
# =====================================================================

# ---------------------------------------------------------------------
#  ** UNVERIFIED PLACEHOLDER DATA **
#  This game's GitHub repo, VPN/community server address, subnet and
#  level-repository were GUESSED from the Earth 2150 naming pattern -
#  they do not point at anything real yet. Confirm/replace before use:
#    GitHub repo : InsideKnightShift/Files
#    VPN server  : vpnnetserver-ks.insideearth.info
#    Subnet      : 10.16.0.0/24
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

$host.ui.RawUI.WindowTitle = "InsideKnightShift Multiplayer Setup"

# Variable Definitions
$Name            = 'InsideKnightShift Community Server'
$ServerHost      = 'vpnnetserver-ks.insideearth.info'
$ValueName       = 'AddressIP'
$IEPort          = 17121
$TWPort          = 17104
$InstallOpenVPN  = $true
$Repo            = 'InsideKnightShift/Files'
$Ref             = 'refs/heads/main'
$Subnet          = '10.16.0.0/24'
$SubnetAliases   = @($Subnet, ($Subnet -replace '/24', '/255.255.255.0'))

# OpenVPN Connect
$OvpnProfileName = 'InsideKnightShift VPN'   # Only profiles with this exact name are ever replaced
$OvpnMsiUrl      = if ($env:PROCESSOR_ARCHITECTURE -eq 'x86') {
                       'https://openvpn.net/downloads/openvpn-connect-v3-windows-x86.msi'
                   } else {
                       'https://openvpn.net/downloads/openvpn-connect-v3-windows.msi'   # x64 (also used on ARM64)
                   }

# Construct the formatted registry string for IP checking
$addressIpFormatted = '"EarthNet - InsideKnightShift""vpnnetserver-ks.insideearth.info""EarthNet - Topware""netserver.earthnet.de"'

# ---------- Status tracking ------------------------------------------
# Each step records exactly one outcome: OK, Skipped, Warning or Failed.
$Results = [ordered]@{}
function Set-StepResult {
    param([string]$Step, [ValidateSet('OK','Skipped','Warning','Failed')][string]$Status, [string]$Detail = '')
    $script:Results[$Step] = [pscustomobject]@{ Status = $Status; Detail = $Detail }
}

# ---------- OpenVPN helpers ------------------------------------------
function Get-OpenVPNConnectExe {
    $candidates = @(
        "${env:ProgramFiles}\OpenVPN Connect\OpenVPNConnect.exe",
        "${env:ProgramFiles(x86)}\OpenVPN Connect\OpenVPNConnect.exe"
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }

    # Fall back to the uninstall registry entry
    $uninstallKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $entry = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
             Where-Object { $_.DisplayName -like 'OpenVPN Connect*' -and $_.InstallLocation } |
             Select-Object -First 1
    if ($entry) {
        $exe = Join-Path $entry.InstallLocation 'OpenVPNConnect.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

# OpenVPNConnect.exe is a GUI-subsystem app, so '&' would not wait for it.
# Start-Process -Wait guarantees each CLI call finishes before the next starts.
function Invoke-OpenVPNCli {
    param([string]$Exe, [string]$Arguments)
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden `
                           -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        [pscustomobject]@{
            ExitCode = $p.ExitCode
            Output   = (Get-Content $outFile -Raw -ErrorAction SilentlyContinue)
            Error    = (Get-Content $errFile -Raw -ErrorAction SilentlyContinue)
        }
    } finally {
        Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-OpenVPNProfiles {
    param([string]$Exe)
    $r = Invoke-OpenVPNCli -Exe $Exe -Arguments '--list-profiles'
    $text = "$($r.Output)"
    $start = $text.IndexOf('[')
    $end   = $text.LastIndexOf(']')
    if ($start -lt 0 -or $end -lt $start) {
        throw "Could not read the existing OpenVPN profile list (exit code $($r.ExitCode))."
    }
    $json = $text.Substring($start, $end - $start + 1)
    # Assign first: on Windows PowerShell 5.1, @($json | ConvertFrom-Json) nests the whole
    # array as a single element, which would break the per-profile name matching below.
    $parsed = $json | ConvertFrom-Json
    return $parsed
}

# Display Banner First
Write-Host
Write-Host " ===================================================" -ForegroundColor Green
Write-Host "   InsideKnightShift Multiplayer Setup v1.1" -ForegroundColor Green
Write-Host " ===================================================" -ForegroundColor Green
Write-Host


# ---------- 1/3) OpenVPN Installation & Profile Setup -----------------
Write-Host
Write-Host " [1/3] OpenVPN Setup..." -ForegroundColor Cyan
if (-not $InstallOpenVPN) {
    Write-Host " - Skipped OpenVPN setup per selection." -ForegroundColor DarkGray
    Set-StepResult 'OpenVPN install' 'Skipped' 'Disabled in script settings'
    Set-StepResult 'OpenVPN profile' 'Skipped' 'Disabled in script settings'
} else {
    # --- 1a) Install OpenVPN Connect ---
    $ovpnCli = Get-OpenVPNConnectExe
    if ($ovpnCli) {
        Write-Host " - OpenVPN Connect is already installed." -ForegroundColor DarkGray
        Set-StepResult 'OpenVPN install' 'OK' 'Already installed'
    } else {
        $msiPath = Join-Path $env:TEMP 'openvpn-connect-v3-windows.msi'
        $msiLog  = Join-Path $env:TEMP 'IKS-OpenVPNConnect-Install.log'
        try {
            Write-Host " - Downloading OpenVPN Connect installer..." -ForegroundColor Yellow
            $oldProgress = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'   # Progress bar makes Invoke-WebRequest very slow on PS 5.1
            try {
                Invoke-WebRequest -Uri $OvpnMsiUrl -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
            } finally {
                $ProgressPreference = $oldProgress
            }

            # Never run an unsigned or tampered installer elevated
            $sig = Get-AuthenticodeSignature -FilePath $msiPath
            if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'OpenVPN') {
                throw "Installer signature check failed (Status: $($sig.Status); Signer: $($sig.SignerCertificate.Subject))."
            }

            Write-Host " - Installing OpenVPN Connect silently..." -ForegroundColor Yellow
            $msi = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart /L*v `"$msiLog`"" -Wait -PassThru

            switch ($msi.ExitCode) {
                0       { }
                3010    { Write-Host " - Installed; Windows reports a restart is required." -ForegroundColor Yellow }
                1641    { Write-Host " - Installed; Windows has started a restart." -ForegroundColor Yellow }
                1618    { throw "Another installation is already in progress. Finish it and re-run this setup." }
                1602    { throw "Installation was cancelled." }
                default { throw "msiexec failed with exit code $($msi.ExitCode). See log: $msiLog" }
            }

            $ovpnCli = Get-OpenVPNConnectExe
            if (-not $ovpnCli) {
                throw "Installer reported success but OpenVPNConnect.exe was not found. See log: $msiLog"
            }

            if ($msi.ExitCode -eq 0) {
                Write-Host " - OpenVPN Connect installed successfully." -ForegroundColor Green
                Set-StepResult 'OpenVPN install' 'OK' 'Installed'
            } else {
                Set-StepResult 'OpenVPN install' 'Warning' 'Installed - restart Windows before connecting'
            }
        } catch {
            Write-Host " ! OpenVPN install failed: $($_.Exception.Message)" -ForegroundColor Red
            Set-StepResult 'OpenVPN install' 'Failed' $_.Exception.Message
            $ovpnCli = $null
        } finally {
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        }
    }

    # --- 1b) Download & import the VPN profile ---
    if (-not $ovpnCli) {
        Write-Host " - Skipping profile import because OpenVPN Connect is not installed." -ForegroundColor DarkGray
        Set-StepResult 'OpenVPN profile' 'Failed' 'Not imported - OpenVPN Connect is not installed'
    } else {
        $ovpnUrl  = "https://raw.githubusercontent.com/$Repo/$Ref/EarthNet/IKS-KnightShift-VPN-TCP.ovpn"
        $ovpnPath = Join-Path $env:TEMP 'IKS-KS-VPN-TCP.ovpn'
        try {
            Write-Host " - Downloading OpenVPN profile configuration..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $ovpnUrl -OutFile $ovpnPath -UseBasicParsing -ErrorAction Stop

            # The CLI cannot edit profiles while the app holds its profile store open
            Stop-Process -Name 'OpenVPNConnect' -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1

            Write-Host " - Checking existing profiles in OpenVPN Connect..." -ForegroundColor Yellow
            $before = @(Get-OpenVPNProfiles -Exe $ovpnCli)

            # Replace ONLY our own profile (matched by exact name). Every other profile is left untouched.
            $ours = @($before | Where-Object { $_.name -eq $OvpnProfileName })
            foreach ($p in $ours) {
                Write-Host " - Replacing previous '$OvpnProfileName' profile..." -ForegroundColor DarkGray
                $rm = Invoke-OpenVPNCli -Exe $ovpnCli -Arguments "--remove-profile=$($p.id)"
                if ($rm.ExitCode -ne 0) { throw "Could not remove old profile $($p.id) (exit code $($rm.ExitCode))." }
            }

            $imp = Invoke-OpenVPNCli -Exe $ovpnCli -Arguments "--accept-gdpr --skip-startup-dialogs --import-profile=`"$ovpnPath`" --name=`"$OvpnProfileName`""
            if ($imp.ExitCode -ne 0) { throw "Import failed (exit code $($imp.ExitCode)). $($imp.Error)" }

            # Verify the result rather than trusting the exit code
            $after       = @(Get-OpenVPNProfiles -Exe $ovpnCli)
            $oursAfter   = @($after | Where-Object { $_.name -eq $OvpnProfileName })
            $othersBefore = @($before | Where-Object { $_.name -ne $OvpnProfileName }).Count
            $othersAfter  = @($after  | Where-Object { $_.name -ne $OvpnProfileName }).Count

            if ($oursAfter.Count -ne 1) {
                throw "Expected 1 '$OvpnProfileName' profile after import, found $($oursAfter.Count)."
            }
            if ($othersAfter -lt $othersBefore) {
                throw "Import removed other profiles ($othersBefore before, $othersAfter after)."
            }

            Write-Host " - OpenVPN profile imported ($($after.Count) profile(s) total, $othersAfter other profile(s) kept)." -ForegroundColor Green
            Set-StepResult 'OpenVPN profile' 'OK' "Imported as '$OvpnProfileName'"
        } catch {
            Write-Host " ! OpenVPN profile setup failed: $($_.Exception.Message)" -ForegroundColor Red
            if (Test-Path $ovpnPath) {
                Write-Host "   Profile saved to: $ovpnPath (import it manually in OpenVPN Connect)." -ForegroundColor Yellow
            }
            Set-StepResult 'OpenVPN profile' 'Failed' $_.Exception.Message
        }
    }
}

# ---------- 2/3) Check & Update Registry Configurations -----------------
Write-Host
Write-Host " [2/3] Checking registry configurations..." -ForegroundColor Cyan

$keyPath = 'HKCU:\Software\Reality Pump\KnightShift\BaseGame\Network\EarthNet'
$needsRegUpdate = $true
if (Test-Path $keyPath) {
    $currentVal  = (Get-ItemProperty -Path $keyPath -Name 'AddressIP' -ErrorAction SilentlyContinue).AddressIP
    $currentPort = (Get-ItemProperty -Path $keyPath -Name 'Port' -ErrorAction SilentlyContinue).Port
    if ($currentVal -eq $addressIpFormatted -and $currentPort -eq $IEPort) { $needsRegUpdate = $false }
}

if (-not $needsRegUpdate) {
    Write-Host " - Registry entry is already configured correctly. Skipping update." -ForegroundColor DarkGray
    Set-StepResult 'Registry' 'OK' 'Already configured'
} else {
    try {
        $backupBase = 'HKCU:\Software\Reality Pump\KnightShift'
        if (Test-Path $backupBase) {
            Write-Host " - Backing up registry key..." -ForegroundColor Yellow
            $desktopPath = [Environment]::GetFolderPath('Desktop')
            $timestamp   = (Get-Date).ToString('yyyyMMdd-HHmmss')
            $backupFile  = Join-Path $desktopPath "IKS-Backup-$timestamp.reg"
            $winRegPath  = $backupBase -replace 'HKCU:\\', 'HKEY_CURRENT_USER\'
            $reg = Start-Process reg.exe -ArgumentList "export `"$winRegPath`" `"$backupFile`" /y" -NoNewWindow -Wait -PassThru
            if ($reg.ExitCode -ne 0 -or -not (Test-Path $backupFile)) {
                throw "Registry backup failed (reg.exe exit code $($reg.ExitCode)); no changes made."
            }
            Write-Host " - Exported backup to: $backupFile" -ForegroundColor DarkGray
        }

        if (-not (Test-Path $keyPath)) { New-Item -Path $keyPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $keyPath -Name 'AddressIP' -Value $addressIpFormatted -Type String -ErrorAction Stop
        Set-ItemProperty -Path $keyPath -Name 'Port' -Value $IEPort -Type DWord -ErrorAction Stop

        # Read back to confirm
        $checkVal  = (Get-ItemProperty -Path $keyPath -Name 'AddressIP' -ErrorAction Stop).AddressIP
        $checkPort = (Get-ItemProperty -Path $keyPath -Name 'Port' -ErrorAction Stop).Port
        if ($checkVal -ne $addressIpFormatted -or $checkPort -ne $IEPort) {
            throw "Values did not persist after writing."
        }

        Write-Host " - Updated registry entries successfully." -ForegroundColor Green
        Set-StepResult 'Registry' 'OK' 'Updated'
    } catch {
        Write-Host " ! Registry update failed: $($_.Exception.Message)" -ForegroundColor Red
        Set-StepResult 'Registry' 'Failed' $_.Exception.Message
    }
}

# ---------- 3/3) Configure Firewall Rules ------------------------------
Write-Host
Write-Host " [3/3] Configuring Windows Firewall Rules..." -ForegroundColor Cyan

$fwRules = @(
    @{ Name = 'IKS - DirectPlay Control (TCP 47624)';   Protocol = 'TCP';    LocalPort = '47624';     RemoteAddress = $Subnet },
    @{ Name = 'IKS - DirectPlay Range (TCP 2300-2400)'; Protocol = 'TCP';    LocalPort = '2300-2400'; RemoteAddress = $Subnet },
    @{ Name = 'IKS - DirectPlay Range (UDP 2300-2400)'; Protocol = 'UDP';    LocalPort = '2300-2400'; RemoteAddress = $Subnet },
    @{ Name = 'IKS - ICMPv4 Allow Subnet';              Protocol = 'ICMPv4'; RemoteAddress = $Subnet }
)

function Test-IKSFirewallRule {
    param($r)
    $existing = @(Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue)
    if ($existing.Count -ne 1) { return $false }
    if ($existing[0].Enabled -ne 'True' -or $existing[0].Action -ne 'Allow' -or $existing[0].Direction -ne 'Inbound') { return $false }
    $addr = @(($existing[0] | Get-NetFirewallAddressFilter).RemoteAddress)[0]
    return ($SubnetAliases -contains $addr)
}

function Set-IKSFirewallRules {
    param($rules)
    foreach ($r in $rules) {
        Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction Stop

        $params = @{
            DisplayName   = $r.Name
            Direction     = 'Inbound'
            Action        = 'Allow'
            Protocol      = $r.Protocol
            Profile       = 'Any'
            RemoteAddress = $r.RemoteAddress
            ErrorAction   = 'Stop'
        }
        if ($r.LocalPort) { $params['LocalPort'] = $r.LocalPort }

        New-NetFirewallRule @params | Out-Null
    }
}

$needsFwUpdate = @($fwRules | Where-Object { -not (Test-IKSFirewallRule $_) }).Count -gt 0

if (-not $needsFwUpdate) {
    Write-Host " - All firewall rules and subnet scopes are already configured correctly. Skipping." -ForegroundColor DarkGray
    Set-StepResult 'Firewall' 'OK' 'Already configured'
} else {
    try {
        Set-IKSFirewallRules -rules $fwRules

        $bad = @($fwRules | Where-Object { -not (Test-IKSFirewallRule $_) } | ForEach-Object { $_.Name })
        if ($bad.Count -gt 0) { throw "Rules not applied correctly: $($bad -join ', ')" }

        Write-Host " - Firewall rules and subnet scope applied successfully." -ForegroundColor Green
        Set-StepResult 'Firewall' 'OK' 'Updated'
    } catch {
        Write-Host " ! Firewall setup failed: $($_.Exception.Message)" -ForegroundColor Red
        Set-StepResult 'Firewall' 'Failed' $_.Exception.Message
    }
}

# ---------- Summary --------------------------------------------------
$failed   = @($Results.Values | Where-Object { $_.Status -eq 'Failed' }).Count
$warnings = @($Results.Values | Where-Object { $_.Status -eq 'Warning' }).Count

$bannerColor = if ($failed) { 'Red' } elseif ($warnings) { 'Yellow' } else { 'Green' }
$statusColor = @{ OK = 'Green'; Skipped = 'DarkGray'; Warning = 'Yellow'; Failed = 'Red' }

Write-Host
Write-Host " ===================================================" -ForegroundColor $bannerColor
Write-Host "   Summary" -ForegroundColor $bannerColor
Write-Host " ===================================================" -ForegroundColor $bannerColor
foreach ($step in $Results.Keys) {
    $r = $Results[$step]
    $line = "   {0,-16} {1,-8} {2}" -f $step, $r.Status, $r.Detail
    Write-Host $line -ForegroundColor $statusColor[$r.Status]
}
Write-Host " ===================================================" -ForegroundColor $bannerColor
if ($failed) {
    Write-Host "   Setup INCOMPLETE - $failed step(s) failed." -ForegroundColor Red
    Write-Host "   Multiplayer will not work until the failures above are fixed." -ForegroundColor Red
} elseif ($warnings) {
    Write-Host "   Setup complete with warnings - see above." -ForegroundColor Yellow
} else {
    Write-Host "   Setup complete. Launch KnightShift and Enjoy!" -ForegroundColor Green
}
Write-Host " ===================================================" -ForegroundColor $bannerColor
Write-Host

Read-Host "Press Enter to exit..."
exit $(if ($failed) { 1 } else { 0 })
