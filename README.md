# TeamsEdu

![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/TeamsEducation?style=for-the-badge)

Import der ASV Daten zu Microsoft Teams über das lokale System. Kein Upload der Daten an Dritte, nebst Microsoft selbst.


## Voraussetzungen

* ASV Export für externe Notenverwaltung
* PowerShell Modul [AzureADPreview](https://www.powershellgallery.com/packages/AzureADPreview/2.0.2.105)
* PowerShell Modul [Microsoft Teams Prerelease](https://www.powershellgallery.com/packages/MicrosoftTeams/1.1.5-preview)
* PowerShell Modul [MSOnline](https://www.powershellgallery.com/packages/MSOnline/1.1.183.57)
* Globale Administrator Rechte für den O365 Tenant


## Installation

1. Microsoft Teams Preview Modul installieren
   ```powershell
   Install-Module -Name MicrosoftTeams -AllowPrerelease 
   ```
1. TeamsEducation Modul installieren
   ```powershell
   Install-Module -Name TeamsEducation 
   ```