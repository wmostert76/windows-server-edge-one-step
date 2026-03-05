$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$wid = [Security.Principal.WindowsIdentity]::GetCurrent()
$wpr = New-Object Security.Principal.WindowsPrincipal($wid)
if (-not $wpr.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Start Windows Terminal als Administrator."
}

function Write-Log([string]$msg) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
}

function Get-UninstallEntries {
    $roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($r in $roots) {
        Get-ItemProperty -Path $r -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, UninstallString, QuietUninstallString, PSChildName
    }
}

function Invoke-UninstallEntry($entry) {
    $name = $entry.DisplayName
    $quiet = $entry.QuietUninstallString
    $normal = $entry.UninstallString
    $guid = $entry.PSChildName

    try {
        if ($guid -match '^\{[0-9A-Fa-f\-]+\}$') {
            Write-Log "MSI uninstall: $name"
            Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
            return
        }

        $cmd = if ($quiet) { $quiet } else { $normal }
        if (-not $cmd) { return }

        if ($cmd -match "MsiExec\.exe" -and $cmd -notmatch "(/quiet|/qn)") { $cmd += " /qn /norestart" }
        if ($cmd -notmatch "MsiExec\.exe" -and $cmd -notmatch "(/quiet|/silent|/s|--silent|--force-uninstall)") { $cmd += " /S" }

        Write-Log "Uninstall: $name"
        Start-Process cmd.exe -ArgumentList "/c $cmd" -Wait -NoNewWindow
    }
    catch {
        Write-Log "Kon niet verwijderen: $name ($($_.Exception.Message))"
    }
}

function Remove-OtherBrowsers {
    $patterns = @("Mozilla Firefox", "Google Chrome", "Chromium", "Brave", "Vivaldi", "Opera")
    $entries = Get-UninstallEntries
    $targets = @(
        foreach ($e in $entries) {
            if ($patterns | Where-Object { $e.DisplayName -like "*$_*" }) { $e }
        }
    ) | Sort-Object DisplayName -Unique

    foreach ($t in $targets) {
        if ($t.DisplayName -like "*Microsoft Edge*") { continue }
        Invoke-UninstallEntry -entry $t
    }
}

function Get-EdgeMsiInfo {
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $data = Invoke-RestMethod "https://edgeupdates.microsoft.com/api/products?view=enterprise"

    $latest = $data |
        Where-Object { $_.Product -eq "Stable" } |
        Select-Object -ExpandProperty Releases |
        Where-Object { $_.Platform -eq "Windows" -and $_.Architecture -eq $arch } |
        Sort-Object { [datetime]$_.PublishedTime } -Descending |
        Select-Object -First 1

    if (-not $latest) { throw "Geen Edge Stable release gevonden." }

    $msi = $latest.Artifacts | Where-Object { $_.ArtifactName -eq "msi" } | Select-Object -First 1
    if (-not $msi) { throw "Geen MSI gevonden voor Edge Stable." }

    [pscustomobject]@{
        Version = $latest.ProductVersion
        Url     = $msi.Location
        Sha256  = $msi.Hash
        Arch    = $arch
    }
}

function Test-EdgeInstalled {
    $edgeExePaths = @(
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($p in $edgeExePaths) {
        if (Test-Path -Path $p) { return $true }
    }

    $edgeEntry = Get-UninstallEntries | Where-Object { $_.DisplayName -like "*Microsoft Edge*" } | Select-Object -First 1
    return [bool]$edgeEntry
}

function Install-EdgeLatest {
    $workDir = "C:\ProgramData\EdgeDeploy"
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null

    $edge = Get-EdgeMsiInfo
    $msiPath = Join-Path $workDir "MicrosoftEdgeEnterprise-$($edge.Arch)-$($edge.Version).msi"

    Write-Log "Download Edge $($edge.Version) ($($edge.Arch))"
    Invoke-WebRequest -Uri $edge.Url -OutFile $msiPath -UseBasicParsing

    Write-Log "Controle SHA256"
    $hash = (Get-FileHash -Path $msiPath -Algorithm SHA256).Hash
    if ($hash -ne $edge.Sha256) { throw "Checksum mismatch. Installatie gestopt." }

    Write-Log "Installeer Edge silent"
    Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -NoNewWindow

    return $workDir
}

function Set-EdgeDefaultBrowser {
    param([string]$workDir)

    $xmlPath = Join-Path $workDir "DefaultAppAssociations.xml"

    $xmlLines = @(
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<DefaultAssociations>',
        '  <Association Identifier=".htm" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />',
        '  <Association Identifier=".html" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />',
        '  <Association Identifier="http" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />',
        '  <Association Identifier="https" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />',
        '</DefaultAssociations>'
    )
    $xmlLines | Set-Content -Path $xmlPath -Encoding UTF8

    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DefaultAssociationsConfiguration" -Value $xmlPath -Type String

    Write-Log "Import default associations"
    Start-Process dism.exe -ArgumentList "/Online /Import-DefaultAppAssociations:`"$xmlPath`"" -Wait -NoNewWindow
}

Write-Log "Start unattended Edge + browser cleanup script"
$dir = "C:\ProgramData\EdgeDeploy"
if (Test-EdgeInstalled) {
    Write-Log "Microsoft Edge gedetecteerd. Installatie wordt overgeslagen."
}
else {
    $dir = Install-EdgeLatest
}
Remove-OtherBrowsers
Set-EdgeDefaultBrowser -workDir $dir
Write-Log "Klaar. Herstart aanbevolen."
