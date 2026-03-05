# OneStep Terminal Installer (Edge Only)

Unattended script voor Windows Server zonder winget:
- Installeert nieuwste Microsoft Edge Enterprise Stable
- Verwijdert 3rd-party browsers (Firefox, Chrome, Chromium, Brave, Vivaldi, Opera)
- Zet Edge als standaard browser

## Actieve one-step installatie (Administrator PowerShell)

```powershell
irm "https://raw.githubusercontent.com/wmostert76/OneStep-Terminal-Installer/master/one-step-install.ps1" | iex
```

## Lokale run

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\one-step-install.ps1
```
