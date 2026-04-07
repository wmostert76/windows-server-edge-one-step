# OneStep Edge Installer (Firefox & Chrome Browser remove)

Unattended script voor Windows Server zonder winget:
- Installeert nieuwste Microsoft Edge Enterprise Stable
- Verwijdert 3rd-party browsers (Firefox, Chrome, Chromium, Brave, Vivaldi, Opera)
- Zet Edge als standaard browser

## Actieve one-step installatie (Administrator PowerShell)

```powershell
irm "https://raw.githubusercontent.com/wmostert76/windows-server-edge-one-step/master/one-step-install.ps1" | iex
```

## Troubleshooting: `irm` TLS / download error

Op oudere Windows Server builds kan `Invoke-RestMethod` falen met:

```text
The underlying connection was closed: An unexpected error occurred on a send.
```

De actuele `one-step-install.ps1` forceert nu zelf TLS 1.2 voor de Edge API-call. Als de eerste bootstrap-download naar GitHub Raw faalt, forceer dan eerst TLS 1.2 en download het script lokaal:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script = "$env:TEMP\one-step-install.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/wmostert76/windows-server-edge-one-step/master/one-step-install.ps1" -OutFile $script
powershell -ExecutionPolicy Bypass -File $script
```

Snelle netwerkcheck als de download nog steeds mislukt:

```powershell
Test-NetConnection raw.githubusercontent.com -Port 443
```

## Lokale run

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\one-step-install.ps1
```

## Auto version releases

Elke push naar `master` maakt automatisch:
- een nieuwe tag (`vX.Y.Z`, patch +1)
- een GitHub Release met release notes
