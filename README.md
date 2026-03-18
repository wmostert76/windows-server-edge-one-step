# OneStep Terminal Installer (Edge Only)

Unattended script voor Windows Server zonder winget:
- Installeert nieuwste Microsoft Edge Enterprise Stable
- Verwijdert 3rd-party browsers (Firefox, Chrome, Chromium, Brave, Vivaldi, Opera)
- Zet Edge als standaard browser

## Actieve one-step installatie (Administrator PowerShell)

```powershell
irm "https://raw.githubusercontent.com/wmostert76/windows-server-edge-one-step/master/one-step-install.ps1" | iex
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
