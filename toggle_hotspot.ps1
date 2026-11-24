Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function WinRT-Await($Task, $Type) {
    $m = $asTaskGeneric.MakeGenericMethod($Type)
    $t = $m.Invoke($null, @($Task))
    $t.Wait(-1) | Out-Null
    $t.Result
}

[void][Windows.Networking.Connectivity.NetworkInformation, Windows, ContentType=WindowsRuntime]
[void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows, ContentType=WindowsRuntime]
[void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult, Windows, ContentType=WindowsRuntime]

$profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
Write-Host "Internet via: $($profile.ProfileName)"

$mgr = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)
Write-Host "Hotspot state: $($mgr.TetheringOperationalState)"

if ($mgr.TetheringOperationalState -eq 'On') {
    Write-Host "Stopping hotspot first..."
    $r = WinRT-Await ($mgr.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
    Write-Host "Stop: $($r.Status)"
    Start-Sleep 3
}

Write-Host "Starting hotspot..."
$r = WinRT-Await ($mgr.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
Write-Host "Start: $($r.Status)"

Start-Sleep 4
Write-Host "=== ipconfig ==="
ipconfig | Select-String 'Local Area Connection\* 11|192\.168\.137|169\.254\.'
