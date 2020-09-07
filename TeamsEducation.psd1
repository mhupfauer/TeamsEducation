﻿@{

# Module Loader File
RootModule = 'loader.psm1'

# Version Number
ModuleVersion = '0.8'

# Unique Module ID
GUID = '6d939bc7-10d8-4fba-9ffe-d24c88e892c1'

# Module Author
Author = 'Markus Hupfauer'

# Company
CompanyName = 'XITASO GmbH'

# Copyright
Copyright = '(c) 2020 XITASO GmbH. All rights reserved.'

# Module Description
Description = 'Migriert ASV Daten des Bundeslands Bayern zu Office 365.
Es wird für jede Klasse (z.B. 5a) und jedes Fach das Schüler dieser Klasse besuchen ein Team angelegt.
Die jeweilig zugeordnete Lehrkraft wird als Eigentümer des Teams gesichert.

Folgende Daten werden durch dieses Script an Microsoft übertragen:
- Vor- / Zunamen von Schülern & Lehrern
- Klassenzusammensetzungen & -bezeichnungen

Genauere Informationen können unter https://github.com/mhupfauer/TeamsEducation eingesehen werden.
'

# Required Modules (will load before this module loads)
RequiredModules = @('AzureADPreview','MicrosoftTeams','MSOnline')


# List of exportable functions
FunctionsToExport = @('Start-MigrationEnv', 'Start-ClassMigration', 'Start-StudentMigration', 'Start-TeacherMigration','Get-DataFromAsvXml')

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'Teams','Education','Deutschland','Bayern','ASV','Schulverwaltung','Gymnasium','Oberstufe','Realschule','Mittelschule','Corona','Homeschooling'

        # A URL to the license for this module.
        LicenseUri = 'https://raw.githubusercontent.com/mhupfauer/TeamsEducation/master/LICENSE.txt'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/mhupfauer/TeamsEducation'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '* Initial release.'

        # Flag to indicate whether the module requires explicit user acceptance for install/update
        RequireLicenseAcceptance = $true

    } # End of PSData hashtable
    
 } # End of PrivateData hashtable


}