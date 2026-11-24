# fix_hotspot_oneoff.ps1  (v4)
# Needs Windows PowerShell 5.1 + Administrator. If you start it from PowerShell 7
# or a non-admin window, it re-launches itself correctly (a UAC prompt will appear).
# Recovers Mobile Hotspot when the host has internet but clients are stuck on
# "No internet" / "Obtaining IP address".
#
# Usage:   .\fix_hotspot_oneoff.ps1
#          .\fix_hotspot_oneoff.ps1 -StopWsl   (also runs "wsl --shutdown" first;
#                                               closes ALL running WSL distros)
param([switch]$StopWsl)

# ---------------------------------------------------------------
# Pre-flight: must be Windows PowerShell 5.1 and elevated
# ---------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($PSVersionTable.PSEdition -eq 'Core' -or -not $isAdmin) {
    if (-not $PSCommandPath) {
        Write-Host '[ERROR] Save this as a .ps1 file and run it from Windows PowerShell (Administrator).' -ForegroundColor Red
        exit 1
    }
    Write-Host '[INFO]  Re-launching in elevated Windows PowerShell 5.1 ...'
    $fwd = if ($StopWsl) { ' -StopWsl' } else { '' }
    Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`"$fwd"
    exit
}

$ErrorActionPreference = 'Stop'

function Ok($m)   { Write-Host "[OK]    $m" -ForegroundColor Green }
function Info($m) { Write-Host "[INFO]  $m" }
function Warn($m) { Write-Host "[WARN]  $m" -ForegroundColor Yellow }

# Hotspot uses a virtual adapter, NOT the physical Wi-Fi card.
$vaPattern = 'Wi-Fi Direct Virtual|Hosted Network Virtual'

# ---------------------------------------------------------------
# WinRT helpers (Mobile Hotspot API)
# ---------------------------------------------------------------
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

[void][Windows.Networking.Connectivity.NetworkInformation,Windows,ContentType=WindowsRuntime]
[void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows,ContentType=WindowsRuntime]
[void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult,Windows,ContentType=WindowsRuntime]
$resultType = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]

function Await-RT($op, [Type]$type) {
    $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $t.Wait(-1) | Out-Null
    $t.Result
}

function New-TetheringManager {
    $script:inetProfile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
    if (-not $script:inetProfile) {
        throw 'Windows reports no active internet connection profile. Connect the host to the internet first.'
    }
    [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($script:inetProfile)
}

function Set-Tethering([bool]$On) {
    $mgr   = New-TetheringManager
    $state = $mgr.TetheringOperationalState.ToString()
    if ($On -and $state -ne 'On') {
        $r = Await-RT ($mgr.StartTetheringAsync()) $resultType
        if ($r.Status.ToString() -ne 'Success') {
            throw "Hotspot start failed: $($r.Status) $($r.AdditionalErrorMessage)"
        }
    } elseif (-not $On -and $state -eq 'On') {
        $r = Await-RT ($mgr.StopTetheringAsync()) $resultType
        if ($r.Status.ToString() -ne 'Success') { Warn "Hotspot stop returned: $($r.Status)" }
    }
}

# ---------------------------------------------------------------
# Other helpers
# ---------------------------------------------------------------
# Old-style ICS ("Allow other network users to connect...") conflicts with
# Mobile Hotspot and is a classic cause of "Obtaining IP address".
function Disable-LegacyICS {
    $share = New-Object -ComObject HNetCfg.HNetShare
    $checked = 0
    $disabled = 0
    foreach ($conn in $share.EnumEveryConnection) {
        $checked++
        try {
            $cfg = $share.INetSharingConfigurationForINetConnection.Invoke($conn)
            if ($cfg.SharingEnabled) {
                $name = $share.NetConnectionProps.Invoke($conn).Name
                $cfg.DisableSharing()
                $disabled++
                Info "Disabled old ICS sharing on '$name'"
            }
        } catch {
            Warn "Could not check one connection for old ICS sharing: $($_.Exception.Message.Trim())"
        }
    }
    Info "Checked $checked connection(s) for old ICS sharing; disabled $disabled"
}

function Reset-SharingServices {
    foreach ($n in 'SharedAccess', 'icssvc') {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($s -and $s.StartType -eq 'Disabled') { Set-Service -Name $n -StartupType Manual }
    }
    Stop-Service icssvc -Force -ErrorAction SilentlyContinue
    Stop-Service SharedAccess -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    Start-Service SharedAccess
    Start-Service icssvc
}

# Finds the hotspot's virtual adapter. Prefers the one that already owns a
# 192.168.137.x address, otherwise any virtual adapter that is Up.
function Find-HotspotAdapter {
    $virtual = @(Get-NetAdapter -ErrorAction SilentlyContinue |
                 Where-Object { $_.InterfaceDescription -match $vaPattern })
    if (-not $virtual.Count) { return $null }
    foreach ($a in $virtual) {
        $own = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
               Where-Object { $_.IPAddress -like '192.168.137.*' }
        if ($own) { return $a }
    }
    $virtual | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
}

# Any real IPv4 on the adapter (not 169.254.x.x, not a duplicate).
# -PreferredOnly additionally requires the address to have finished DAD.
function Get-HotspotIPv4($adapter, [switch]$PreferredOnly) {
    $r = @(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
           Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.AddressState -ne 'Duplicate' })
    if ($PreferredOnly) { $r = @($r | Where-Object { $_.AddressState -eq 'Preferred' }) }
    $r
}

function Wait-HotspotIP([int]$Seconds) {
    for ($i = 0; $i -lt $Seconds; $i++) {
        $a = Find-HotspotAdapter
        if ($a -and @(Get-HotspotIPv4 $a).Count) { return $a }
        Start-Sleep 1
    }
    return $null
}

# Removes leftover IPv4 addresses / 192.168.137.x routes on the hotspot virtual
# adapters, in BOTH the active and the persistent store. Stale entries here make
# Windows answer "The object already exists" and leave the adapter without IP.
function Clear-StaleHotspotConfig {
    $idx = @(Get-NetAdapter -ErrorAction SilentlyContinue |
             Where-Object { $_.InterfaceDescription -match $vaPattern } |
             ForEach-Object { $_.ifIndex })
    foreach ($i in $idx) {
        try { Set-NetIPInterface -InterfaceIndex $i -AddressFamily IPv4 -Dhcp Disabled -ErrorAction Stop } catch { }
    }
    foreach ($store in 'ActiveStore', 'PersistentStore') {
        try {
            Get-NetIPAddress -AddressFamily IPv4 -PolicyStore $store -ErrorAction SilentlyContinue |
                Where-Object { $idx -contains $_.InterfaceIndex } |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
            Get-NetRoute -AddressFamily IPv4 -PolicyStore $store -ErrorAction SilentlyContinue |
                Where-Object { $idx -contains $_.InterfaceIndex -and $_.DestinationPrefix -like '192.168.137.*' } |
                Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        } catch { }
    }
}

# Last resort: give the hotspot adapter its static IP ourselves.
function Set-HotspotStaticIP($adapter) {
    try {
        New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress 192.168.137.1 -PrefixLength 24 | Out-Null
    } catch {
        Warn "New-NetIPAddress failed ($($_.Exception.Message.Trim())) - trying netsh"
        netsh interface ip set address name="$($adapter.Name)" static 192.168.137.1 255.255.255.0 | Out-Null
    }
}

# Who is listening on the given UDP ports? (ICS DHCP = UDP 67, ICS DNS proxy = UDP 53)
function Get-UdpOwners([int[]]$Ports) {
    $icsPid = 0
    try { $icsPid = [int](Get-CimInstance Win32_Service -Filter "Name='SharedAccess'" -ErrorAction Stop).ProcessId } catch { }
    foreach ($e in @(Get-NetUDPEndpoint -LocalPort $Ports -ErrorAction SilentlyContinue)) {
        $p = Get-Process -Id $e.OwningProcess -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Port    = $e.LocalPort
            Local   = $e.LocalAddress
            PID     = $e.OwningProcess
            Process = $(if ($p) { $p.ProcessName } else { '?' })
            IsIcs   = ($icsPid -ne 0 -and $e.OwningProcess -eq $icsPid)
        }
    }
}

function Show-HotspotDiag {
    try {
        Write-Host ""
        Write-Host "--- DIAGNOSTICS (send this output if the problem persists) ---"
        Write-Host "Adapters:"
        Get-NetAdapter -ErrorAction SilentlyContinue |
            Format-Table Name, InterfaceDescription, Status, ifIndex -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "IPv4 addresses (active):"
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Format-Table InterfaceAlias, IPAddress, PrefixLength, AddressState -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "IPv4 addresses (persistent):"
        Get-NetIPAddress -AddressFamily IPv4 -PolicyStore PersistentStore -ErrorAction SilentlyContinue |
            Format-Table InterfaceAlias, IPAddress, PrefixLength -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "Virtual adapter IP interfaces:"
        Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -like 'Local Area Connection*' } |
            Format-Table InterfaceAlias, Dhcp, ConnectionState -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "UDP listeners on 53 / 67 (ICS = SharedAccess):"
        Get-UdpOwners 53, 67 | Format-Table Port, Local, PID, Process, IsIcs -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "WinNAT (Get-NetNat, used by WSL/Docker):"
        Get-NetNat -ErrorAction SilentlyContinue | Format-Table Name, InternalIPInterfaceAddressPrefix, Active -AutoSize |
            Out-String -Width 200 | Write-Host
        Write-Host "Services:"
        Get-Service SharedAccess, icssvc, mpssvc, BFE -ErrorAction SilentlyContinue |
            Format-Table Name, Status, StartType -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "--- END DIAGNOSTICS ---"
    } catch { }
}

function Test-HotspotPath($hot, $hostIp) {
    Write-Host ""
    Write-Host "=== PATH TEST (host side) - why clients may say 'No internet' ==="

    # a) Clients use the hotspot IP as their DNS server (ICS DNS proxy)
    $dnsOk = $false
    try {
        Resolve-DnsName 'www.google.com' -Type A -Server $hostIp -DnsOnly -QuickTimeout -ErrorAction Stop | Out-Null
        $dnsOk = $true
    } catch { }
    Write-Host ("ICS DNS proxy answers on $hostIp  : " + $(if ($dnsOk) { 'YES' } else { 'NO' }))
    if (-not $dnsOk) {
        $o53 = @(Get-UdpOwners 53)
        Warn ('Clients will connect but show "No internet" because DNS fails. UDP 53 listeners: ' +
              $(if ($o53.Count) { (($o53 | ForEach-Object { "$($_.Process)($($_.Local))" }) -join ', ') } else { 'none' }))
    }

    # b) Has any client actually received a lease?
    $clients = @(Get-NetNeighbor -InterfaceIndex $hot.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -like '192.168.137.*' -and $_.IPAddress -ne $hostIp -and
            $_.LinkLayerAddress -and $_.LinkLayerAddress -ne 'FF-FF-FF-FF-FF-FF' -and
            $_.State -notin 'Unreachable', 'Incomplete', 'Permanent'
        })
    if ($clients.Count) {
        Write-Host ("Clients seen on the hotspot    : " + (($clients | ForEach-Object { "$($_.IPAddress) [$($_.LinkLayerAddress)]" }) -join ', '))
    } else {
        Write-Host 'Clients seen on the hotspot    : none yet (connect a device, then run: Get-NetNeighbor -AddressFamily IPv4 | ? IPAddress -like 192.168.137.*)'
    }

    # c) Forwarding flags
    $fw = (Get-NetIPInterface -InterfaceIndex $hot.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).Forwarding
    Write-Host "IPv4 forwarding on hotspot if. : $fw"

    # d) WinNAT (WSL / Docker) can fight with the ICS NAT used by Mobile Hotspot
    $nats = @(Get-NetNat -ErrorAction SilentlyContinue)
    if ($nats.Count) {
        Warn ("WinNAT is active ($(($nats | ForEach-Object { $_.Name }) -join ', ')) - usually WSL/Docker/Hyper-V. It can break the hotspot's NAT. Re-run with -StopWsl to test.")
    } else {
        Write-Host 'WinNAT (WSL/Docker)            : none'
    }

    # e) Group policy that blocks Internet Connection Sharing
    $gp = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections' -ErrorAction SilentlyContinue
    if ($gp -and $gp.PSObject.Properties['NC_ShowSharedAccessUI'] -and $gp.NC_ShowSharedAccessUI -eq 0) {
        Warn 'A policy (NC_ShowSharedAccessUI = 0) prohibits Internet Connection Sharing - the hotspot cannot route traffic.'
    }

    Write-Host ""
    Write-Host 'CLIENT TEST to isolate the problem - on the phone/laptop set a STATIC IP:'
    Write-Host '    IP 192.168.137.50   Subnet 255.255.255.0   Gateway 192.168.137.1   DNS 8.8.8.8'
    Write-Host '    Internet works      -> only DNS/DHCP on the host is broken (see answers above).'
    Write-Host '    Still no internet   -> NAT/forwarding is broken (WSL/Docker conflict, VPN, security software).'
}

# ---------------------------------------------------------------
# Main
# ---------------------------------------------------------------
try {
    $manualIp = $false

    # 1. Verify host internet (TCP 443 - works even if ICMP is blocked)
    if (-not (Test-NetConnection -ComputerName 1.1.1.1 -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)) {
        throw 'Host has no internet. Fix the host connection first.'
    }
    Ok 'Host internet reachable'

    Clear-DnsClientCache
    try {
        Resolve-DnsName 'www.google.com' -Type A -QuickTimeout -ErrorAction Stop | Out-Null
        Ok 'Host DNS works'
    } catch {
        Warn 'Host cannot resolve DNS - clients will show "No internet" even if the hotspot itself works. Check the host DNS settings / VPN.'
    }

    # 2. Turn hotspot OFF so nothing is holding the sharing config
    Set-Tethering $false
    Start-Sleep 3
    Ok 'Hotspot stopped'

    if ($StopWsl) {
        # WSL2 / Hyper-V virtual switches also rely on the ICS/NAT stack.
        try { & wsl.exe --shutdown; Start-Sleep 5; Ok 'WSL shut down' }
        catch { Warn "wsl --shutdown failed: $($_.Exception.Message.Trim())" }
    }

    # 3. Remove conflicting classic ICS sharing
    try { Disable-LegacyICS } catch { Warn "Could not check old ICS sharing: $($_.Exception.Message)" }

    # 4. Clear leftover IP config on the hotspot virtual adapters, restart services
    Clear-StaleHotspotConfig
    Reset-SharingServices
    Ok 'Sharing services restarted (SharedAccess, icssvc)'

    # 5. Turn hotspot ON and wait for the adapter to get its IP
    #    (the adapter is the DHCP *server* side: it must hold a static IP,
    #     normally 192.168.137.1 - never set it to DHCP)
    Set-Tethering $true
    Ok 'Hotspot started'
    $hot = Wait-HotspotIP 20

    if (-not $hot) {
        Warn 'Hotspot adapter has no IPv4 - clearing leftover config and restarting hotspot once'
        Clear-StaleHotspotConfig
        Set-Tethering $false
        Start-Sleep 3
        Clear-StaleHotspotConfig
        Set-Tethering $true
        $hot = Wait-HotspotIP 20
    }

    if (-not $hot) {
        $cand = Find-HotspotAdapter
        if (-not $cand) {
            Show-HotspotDiag
            throw 'Hotspot adapter (Wi-Fi Direct Virtual Adapter) not found. Check that the Wi-Fi radio is on and update the Wi-Fi driver.'
        }
        Warn "Windows did not assign an IP to '$($cand.Name)' - assigning 192.168.137.1/24 manually"
        Clear-StaleHotspotConfig
        Set-HotspotStaticIP $cand
        $manualIp = $true
        $hot = Wait-HotspotIP 15
    }

    if (-not $hot) {
        Show-HotspotDiag
        throw 'Hotspot adapter still has no IPv4 address. See diagnostics above.'
    }

    # The address may need a few seconds to finish duplicate-address detection.
    for ($i = 0; $i -lt 15 -and -not @(Get-HotspotIPv4 $hot -PreferredOnly).Count; $i++) { Start-Sleep 1 }
    if (-not @(Get-HotspotIPv4 $hot -PreferredOnly).Count) {
        Warn 'The hotspot IP is present but not yet in Preferred state.'
    }
    Ok "Hotspot adapter: $($hot.Name) ($((Get-HotspotIPv4 $hot).IPAddress -join ', '))"

    # 6. Enable IPv4 forwarding on the internet-facing adapter and the hotspot adapter
    $wan = $null
    try {
        $guid = $script:inetProfile.NetworkAdapter.NetworkAdapterId.ToString('B')
        $wan  = Get-NetAdapter | Where-Object { $_.InterfaceGuid -eq $guid } | Select-Object -First 1
    } catch { }
    if (-not $wan) { Warn 'Could not identify the internet-facing adapter; forwarding set on hotspot adapter only.' }
    foreach ($a in @($wan, $hot) | Where-Object { $_ }) {
        Set-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -Forwarding Enabled
    }
    Ok 'IP forwarding enabled'

    # 7. Firewall: allow only DHCP (UDP 67/68) and DNS (53) inbound.
    #    Also removes the old allow-everything rule from the first script.
    foreach ($n in 'HotspotAllowInbound', 'HotspotAllowInbound-UDP', 'HotspotAllowInbound-TCP') {
        Remove-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue
    }
    New-NetFirewallRule -DisplayName 'HotspotAllowInbound-UDP' -Direction Inbound -Action Allow `
        -Protocol UDP -LocalPort 53, 67, 68 | Out-Null
    New-NetFirewallRule -DisplayName 'HotspotAllowInbound-TCP' -Direction Inbound -Action Allow `
        -Protocol TCP -LocalPort 53 | Out-Null
    Ok 'Firewall rules added (DHCP + DNS only)'

    # 8. Verification
    $svcOk = (Get-Service SharedAccess).Status -eq 'Running'
    $hsOk  = (Get-Service icssvc).Status -eq 'Running'
    $mgr   = New-TetheringManager
    $isOn  = $mgr.TetheringOperationalState.ToString() -eq 'On'
    $hotIP = (Get-HotspotIPv4 $hot).IPAddress
    $ssid  = $mgr.GetCurrentAccessPointConfiguration().Ssid

    $owners67 = @(Get-UdpOwners 67)
    $dhcpIcs  = @($owners67 | Where-Object { $_.IsIcs }).Count -gt 0
    $dhcpText = if ($dhcpIcs) { 'YES (ICS / SharedAccess)' }
                elseif ($owners67.Count) { 'NO - port 67 is held by: ' + (($owners67 | ForEach-Object { $_.Process }) -join ', ') }
                else { 'NO - nothing is listening' }

    Write-Host ""
    Write-Host "=== VERIFICATION ==="
    Write-Host ("ICS service (SharedAccess) : " + $(if ($svcOk) { 'YES' } else { 'NO' }))
    Write-Host ("Hotspot service (icssvc)   : " + $(if ($hsOk)  { 'YES' } else { 'NO' }))
    Write-Host ("Hotspot state ON           : " + $(if ($isOn)  { 'YES' } else { 'NO' }))
    Write-Host ("Hotspot IP                 : " + ($hotIP -join ', '))
    Write-Host ("IP assigned by             : " + $(if ($manualIp) { 'this script (Windows did not)' } else { 'Windows' }))
    Write-Host ("DHCP server on UDP 67      : $dhcpText")

    if ($svcOk -and $hsOk -and $isOn -and $hotIP) {
        Write-Host "[OK] Hotspot is up - SSID '$ssid'. On each client: forget the network, toggle Wi-Fi off/on, reconnect." -ForegroundColor Green
    } else {
        Warn 'Some check failed - see output above.'
        Show-HotspotDiag
    }

    $hostIp = @($hotIP)[0]
    Test-HotspotPath $hot $hostIp
    if (-not $dhcpIcs -or $manualIp) {
        Warn 'The DHCP server may not be answering - see the static-IP test above.'
        Show-HotspotDiag
    }
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}