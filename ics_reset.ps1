Stop-Service icssvc -Force -ErrorAction SilentlyContinue
Stop-Service SharedAccess -Force -ErrorAction SilentlyContinue
Stop-Service WinNat -Force -ErrorAction SilentlyContinue
Start-Sleep 3

Get-NetNat | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue

Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters' -Name 'ScopeAddress' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters' -Name 'ScopeAddressBackup' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters' -Name 'StandaloneDhcpAddress' -ErrorAction SilentlyContinue

$ha = (Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wi-Fi Direct*' -and $_.Status -eq 'Up' } | Select-Object -First 1).Name
if ($ha) {
    Remove-NetIPAddress -InterfaceAlias $ha -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
}

Start-Service SharedAccess
Start-Sleep 3
Start-Service icssvc
Start-Sleep 5

ipconfig | Select-String 'Local Area|192\.168\.|169\.254\.'
Get-Service SharedAccess, icssvc | Select-Object Name, Status
