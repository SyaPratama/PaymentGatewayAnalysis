# fix-hotspot.ps1 — Jalankan sebagai Administrator
# Usage: klik kanan → Run with PowerShell (as Administrator)

#Requires -RunAsAdministrator

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== HOTSPOT FIX SCRIPT ===" -ForegroundColor Cyan

# ── 1. Pastikan internet host OK ──────────────────────────────────────────────
Write-Host "`n[1] Cek internet host..." -ForegroundColor Yellow
$ping = Test-NetConnection -ComputerName 8.8.8.8 -InformationLevel Quiet -WarningAction SilentlyContinue
if (-not $ping) {
    Write-Host "    Host tidak ada internet. Cek Ethernet/USB dulu." -ForegroundColor Red
    Read-Host "Tekan Enter untuk keluar"
    exit 1
}
Write-Host "    Host internet OK (Ethernet up)" -ForegroundColor Green

# ── 2. Bersihkan NAT lama ─────────────────────────────────────────────────────
Write-Host "`n[2] Bersihkan NAT lama..." -ForegroundColor Yellow
Remove-NetNat * -Confirm:$false
Write-Host "    NAT dibersihkan" -ForegroundColor Green

# ── 3. Pastikan services running ──────────────────────────────────────────────
Write-Host "`n[3] Restart services ICS + icssvc..." -ForegroundColor Yellow
Stop-Service icssvc      -Force
Stop-Service SharedAccess -Force
Start-Sleep 2
Start-Service SharedAccess
Start-Sleep 1
Start-Service icssvc
Start-Sleep 2
Write-Host "    Services: $($(Get-Service SharedAccess).Status) / $($(Get-Service icssvc).Status)" -ForegroundColor Green

# ── 4. Nyalakan hotspot via WinRT API ─────────────────────────────────────────
Write-Host "`n[4] Nyalakan Mobile Hotspot..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq 'AsTask' -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        })[0]

    function WinRT-Await($Task, $Type) {
        $method  = $asTaskGeneric.MakeGenericMethod($Type)
        $netTask = $method.Invoke($null, @($Task))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }

    [void][Windows.Networking.Connectivity.NetworkInformation,        Windows, ContentType = WindowsRuntime]
    [void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows, ContentType = WindowsRuntime]
    [void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult, Windows, ContentType = WindowsRuntime]

    $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
    $mgr     = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)

    Write-Host "    Status saat ini: $($mgr.TetheringOperationalState)" -ForegroundColor Gray

    if ($mgr.TetheringOperationalState -ne 'On') {
        $task   = $mgr.StartTetheringAsync()
        $result = WinRT-Await $task ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
        Write-Host "    Hasil: $($result.Status)" -ForegroundColor $(if ($result.Status -eq 'Success') { 'Green' } else { 'Red' })
    } else {
        Write-Host "    Hotspot sudah ON" -ForegroundColor Green
    }
} catch {
    Write-Host "    WinRT gagal: $_" -ForegroundColor Red
    Write-Host "    Coba netsh fallback..." -ForegroundColor Yellow
    netsh wlan set hostednetwork mode=allow ssid="TAMA" key="JIR123456789" | Out-Null
    netsh wlan start hostednetwork | Out-Null
}

Start-Sleep 3

# ── 5. Temukan adapter hotspot ────────────────────────────────────────────────
Write-Host "`n[5] Deteksi adapter hotspot..." -ForegroundColor Yellow
$hotspotAdapter = Get-NetAdapter |
    Where-Object { ($_.InterfaceDescription -like '*Wi-Fi Direct*' -or $_.Name -like 'Local Area Connection*') -and $_.Status -eq 'Up' } |
    Select-Object -First 1

if (-not $hotspotAdapter) {
    Write-Host "    Adapter hotspot tidak ditemukan!" -ForegroundColor Red
    Write-Host "    Pastikan Wi-Fi radio ON (Fn+F2 atau Action Center)" -ForegroundColor Yellow
    Read-Host "Tekan Enter untuk keluar"
    exit 1
}
Write-Host "    Adapter: $($hotspotAdapter.Name)" -ForegroundColor Green

# ── 6. Buat NAT baru ──────────────────────────────────────────────────────────
Write-Host "`n[6] Buat NAT rule..." -ForegroundColor Yellow
$subnet = "192.168.137.0/24"
New-NetNat -Name HotspotNAT -InternalIPInterfaceAddressPrefix $subnet | Out-Null
Write-Host "    NAT HotspotNAT → $subnet" -ForegroundColor Green

# ── 7. Pastikan IP forwarding Ethernet aktif ──────────────────────────────────
Write-Host "`n[7] Enable IP forwarding..." -ForegroundColor Yellow
Set-NetIPInterface -InterfaceAlias 'Ethernet' -Forwarding Enabled
Set-NetIPInterface -InterfaceAlias $hotspotAdapter.Name -Forwarding Enabled
Write-Host "    IP forwarding OK" -ForegroundColor Green

# ── 8. Set DNS pada adapter hotspot ───────────────────────────────────────────
Write-Host "`n[8] Set DNS hotspot adapter..." -ForegroundColor Yellow
Set-DnsClientServerAddress -InterfaceAlias $hotspotAdapter.Name -ServerAddresses '8.8.8.8','1.1.1.1'
Write-Host "    DNS: 8.8.8.8, 1.1.1.1" -ForegroundColor Green

# ── 9. Firewall: allow hotspot subnet ─────────────────────────────────────────
Write-Host "`n[9] Firewall rules..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
# Allow inbound dari subnet hotspot
$fwRule = 'HotspotAllowInbound'
Remove-NetFirewallRule -DisplayName $fwRule -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $fwRule `
    -Direction Inbound `
    -Action Allow `
    -LocalAddress 192.168.137.1 `
    -RemoteAddress 192.168.137.0/24 `
    -Protocol Any | Out-Null
Write-Host "    Firewall OK" -ForegroundColor Green

# ── 10. Verifikasi akhir ──────────────────────────────────────────────────────
Write-Host "`n[10] Verifikasi..." -ForegroundColor Yellow
$natOK  = (Get-NetNat -Name HotspotNAT -ErrorAction SilentlyContinue).Active
$svcOK  = (Get-Service SharedAccess).Status -eq 'Running'
$icssvc = (Get-Service icssvc).Status -eq 'Running'
$inetOK = Test-NetConnection -ComputerName 8.8.8.8 -InformationLevel Quiet -WarningAction SilentlyContinue

Write-Host ""
Write-Host "    NAT Active   : $(if ($natOK)  { 'YES ✓' } else { 'NO ✗' })" -ForegroundColor $(if ($natOK)  { 'Green' } else { 'Red' })
Write-Host "    ICS Service  : $(if ($svcOK)  { 'YES ✓' } else { 'NO ✗' })" -ForegroundColor $(if ($svcOK)  { 'Green' } else { 'Red' })
Write-Host "    icssvc       : $(if ($icssvc) { 'YES ✓' } else { 'NO ✗' })" -ForegroundColor $(if ($icssvc) { 'Green' } else { 'Red' })
Write-Host "    Host Internet: $(if ($inetOK) { 'YES ✓' } else { 'NO ✗' })" -ForegroundColor $(if ($inetOK) { 'Green' } else { 'Red' })

Write-Host ""
if ($natOK -and $svcOK -and $inetOK) {
    Write-Host "=== SELESAI. Hotspot siap. Connect device ke SSID: TAMA ===" -ForegroundColor Cyan
} else {
    Write-Host "=== Ada yang gagal. Cek output di atas. ===" -ForegroundColor Red
    Write-Host "    Jika Wi-Fi radio mati: tekan Fn+F2 atau enable Wi-Fi di Action Center" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Tekan Enter untuk keluar"
