$wifi = Get-PnpDevice | Where-Object { $_.FriendlyName -like '*RZ616*' -or ($_.FriendlyName -like '*Wi-Fi*' -and $_.FriendlyName -notlike '*Virtual*' -and $_.FriendlyName -notlike '*Direct*') } | Select-Object -First 1
Write-Host "Device: $($wifi.FriendlyName) - Status: $($wifi.Status)"

# RF Kill state (0=on, 1=off)
$rfpath = 'HKLM:\SYSTEM\CurrentControlSet\Control\RadioManagement\SystemRadioState'
$rfstate = (Get-ItemProperty $rfpath -ErrorAction SilentlyContinue).SystemRadioState
Write-Host "RF Kill State: $rfstate (0=enabled, 1=disabled)"

if ($rfstate -eq 1) {
    Write-Host "RF Kill aktif! Matikan airplane mode via Action Center."
} else {
    Write-Host "RF Kill OK"
}

# Coba enable via PnP
if ($wifi -and $wifi.Status -ne 'OK') {
    Enable-PnpDevice -InstanceId $wifi.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep 3
}

# Cek WLAN service
$wlan = Get-Service WlanSvc -ErrorAction SilentlyContinue
Write-Host "WlanSvc: $($wlan.Status)"
if ($wlan.Status -ne 'Running') {
    Start-Service WlanSvc
    Start-Sleep 2
}

Get-NetAdapter -Name 'Wi-Fi' | Select-Object Name, Status
netsh wlan show interfaces 2>&1 | Select-String 'State|Radio'
