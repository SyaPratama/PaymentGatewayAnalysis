# Full fix: DHCP reset + WinRT hotspot ON
# Run as Administrator

# 1. Hapus semua NAT
Get-NetNat | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue

# 2. Set DHCP pada adapter hotspot (jika Up)
$ha = (Get-NetAdapter | Where-Object {
    ($_.InterfaceDescription -like '*Wi-Fi Direct*' -or $_.Name -like 'Local Area Connection*') -and $_.Status -eq 'Up'
} | Select-Object -First 1).Name

if ($ha) {
    netsh interface ip set address name=$ha source=dhcp | Out-Null
    netsh interface ip set dns name=$ha source=dhcp | Out-Null
    Write-Host "DHCP set on: $ha"
}

# 3. Restart services
Stop-Service icssvc -Force -ErrorAction SilentlyContinue
Stop-Service SharedAccess -Force -ErrorAction SilentlyContinue
Start-Sleep 3
Start-Service SharedAccess
Start-Sleep 2
Start-Service icssvc
Start-Sleep 3

# 4. Nyalakan hotspot via WinRT
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$ag = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function WRT($task,$rtype){ $m=$ag.MakeGenericMethod($rtype); $x=$m.Invoke($null,@($task)); $x.Wait(-1)|Out-Null; $x.Result }
[void][Windows.Networking.Connectivity.NetworkInformation, Windows, ContentType=WindowsRuntime]
[void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows, ContentType=WindowsRuntime]
[void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult, Windows, ContentType=WindowsRuntime]

$profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
$mgr = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)

if ($mgr.TetheringOperationalState -ne 'On') {
    $r = WRT ($mgr.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
    Write-Host "Hotspot Start: $($r.Status)"
} else {
    Write-Host "Hotspot already On"
}

Start-Sleep 5

# 5. Cek IP setelah hotspot ON
$ha = (Get-NetAdapter | Where-Object {
    ($_.InterfaceDescription -like '*Wi-Fi Direct*' -or $_.Name -like 'Local Area Connection*') -and $_.Status -eq 'Up'
} | Select-Object -First 1).Name
Write-Host "Hotspot adapter: $ha"

netsh interface ip show config name=$ha

# 6. Enable IP forwarding
Set-NetIPInterface -InterfaceAlias 'Ethernet' -Forwarding Enabled -ErrorAction SilentlyContinue

Write-Host "Done."
