function global:Test-WindowsVersion {

    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object BuildNumber
    $buildNumber = $osInfo.BuildNumber
    
    if ($buildNumber -gt 19045) {
        $global:ScriptContext.isWin11 = $true
    }
    else {
        $global:ScriptContext.isWin11 = $false
    }
}