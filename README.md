# TeamsEdu

Import der ASV Daten zu Microsoft Teams über das lokale System. Kein Upload der Daten an Dritte, nebst Microsoft selbst.


## Voraussetzungen

* ASV Export für externe Notenverwaltung
* PowerShell Modul [AzureADPreview](https://www.powershellgallery.com/packages/AzureADPreview/2.0.2.105)
* PowerShell Modul [Microsoft Teams Prerelease](https://www.powershellgallery.com/packages/MicrosoftTeams/1.1.5-preview)
* PowerShell Modul [MSOnline](https://www.powershellgallery.com/packages/MSOnline/1.1.183.57)
* Globale Administrator Rechte für den O365 Tenant


## Tutorial

1. ASV Export starten und .ZIP Datei entpacken
2. TeamsEdu Modul installieren

   `Install-Module TeamsEdu`
3. ASV Daten importieren 

   `$data = Get-DataFromAsvXML -XMLPath [PFAD ZUR export.xml]`
4. Schüler importieren (Testlauf)

   `Start-StudentMigration -data $data -AADUserOutput [PFAD FÜR NUTZERLISTE] -Suffix [Suffix für UPN] -WhatIf $true`
5. Datei die für AADUserOutput angelegt wurde überprüfen
6. Schüler importieren

   `Start-StudentMigration -data $data -AADUserOutput [PFAD FÜR NUTZERLISTE] -Suffix [Suffix für UPN] -WhatIf $true`
7. Leher importieren (Testlauf)

    `Start-TeacherMigration -data $data -AADUserOutput [PFAD FÜR NUTZERLISTE] -Suffix [Suffix für UPN] -ExemptListPath <Pfad für ausgenommene Lehrkräfte> -WhatIf $true`
8. Datei die für AADUserOutput angelegt wurde überprüfen
9. Leher importieren (Testlauf)

    `Start-TeacherMigration -data $data -AADUserOutput [PFAD FÜR NUTZERLISTE] -Suffix [Suffix für UPN] -ExemptListPath <Pfad für ausgenommene Lehrkräfte>`
10. Klassen erstellen

   `Start-ClassMigration -data $data -Suffix [Suffix für UPN] -IncludeSeniors <$false, Klassen 11 & 12 werden aus ASV importiert | $true, Klassen 11 & 12 werden nicht aus der ASV importiert>`