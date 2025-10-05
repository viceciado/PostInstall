$p = "$env:windir\Setup\Scripts"
$t = "$p\PostInstall.ps1"

do {
    try {
        $null = Invoke-WebRequest -Uri "https://api.github.com" -Method Head -TimeoutSec 5 -UseBasicParsing
        break
    }
    catch {
        Start-Sleep 10
    }
} while ($true)

$r = Invoke-RestMethod -Uri "https://api.github.com/repos/viceciado/PostInstall/releases/latest" -Headers @{"User-Agent"="PowerShell"} -TimeoutSec 30
$a = $r.assets | ? { $_.name -eq "PostInstall.ps1" }

if (-not (Test-Path $p)) {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
}

$w = New-Object System.Net.WebClient
$w.Headers.Add("User-Agent", "PowerShell")
$f = "$env:TEMP\PostInstall_temp.ps1"
$w.DownloadFile($a.browser_download_url, $f)

$c = Get-Content -Path $f -Raw -Encoding UTF8
$u = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($t, $c, $u)

Remove-Item $f -Force -ErrorAction SilentlyContinue
$w.Dispose()

$cp = Get-ExecutionPolicy -Scope CurrentUser
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$t`"" -WindowStyle Hidden -PassThru | Out-Null
Set-ExecutionPolicy -ExecutionPolicy $cp -Scope CurrentUser -Force