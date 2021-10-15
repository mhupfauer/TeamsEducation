function Generate-ClassToGroupHashTable
{ 
  param
  (
    [Parameter(Mandatory=$true)]
    $data
  )
  $klassendata = @{}
  foreach ($k in $data.Klassen)
  {
    foreach ($kg in $k.KlassenGruppen)
    {
      $klassendata.Add($kg.KlassenGruppenId, $k.Klassenname)
    }
  }
  return $klassendata
}

function Generate-SchuelerIdToObjTable()
{
  param
  (
    [parameter(
        Mandatory = $true
    )]
    $data,
    [parameter(
        Mandatory = $true
    )]
    $Format,    
    [parameter(
        Mandatory = $true
    )]
    $aadusers
  )

  $SchuelerIdToObjTable = @{}
  
  foreach($klasse in $data.Klassen)
  {
    foreach($schueler in $klasse.KlassenGruppen.Klassenliste)
    {
      $upn = Get-Upn -vorname ($schueler.Vorname) -nachname ($schueler.Familienname) -gebdat ($schueler.GebDatum) -klasse ($klasse.Klassenname) -format $Format
      $SchuelerIdToObjTable.($schueler.SchuelerId) += @(($aadusers.$upn))
    }
  }
  return $SchuelerIdToObjTable  
}

function Generate-TeacherIdToObjTable()
{
  param
  (
    [parameter(
        Mandatory = $true
    )]
    $data,
    [parameter(
        Mandatory = $true
    )]
    $Format,
    [parameter(
        Mandatory = $true
    )]
    $aadusers
  )

  $TeacherIdToObjTable = @{}
  
  foreach($teacher in $data.Lehrer)
  {
    $upn =  Get-Upn -vorname ($teacher.Vorname) -nachname ($teacher.Familienname) -format $Format
    $TeacherIdToObjTable.($teacher.TeacherId) += @(($aadusers.$upn))
  }
  return $TeacherIdToObjTable  
}
function Generate-CoursesStudentTbl
{
  param
  (
    [parameter(
        Mandatory = $true
    )]
    $data
  )
  
  $CourseStudentMap = @{}
  
  foreach($kl in $data.Klassen.Klassengruppen.Klassenliste)
  {
    foreach($bf in $kl.BesuchteFaecher)
    {
      if(-not $null -eq $bf)
      {
        $CourseStudentMap.$bf += @(($kl.SchuelerId))
      }
    }
  }
  return $CourseStudentMap
}

function Start-ClassMigration
{
  <#
      .Synopsis
      Creates class teams in Microsoft Teams.

      .Description
      Reads ASV Data from Get-DataFromAsvXml and creates classes based on Unterrichtselemente.
      Has to be run after Start-StudentMigration and Start-TeacherMigration, otherwise there will be no users / teachers inside the teams.

      .Parameter data
      Object returned from Get-DataFromAsvXml
 
      .Parameter FormatPupil
      UPN Format "{0}.{1}.{2}.schueler@domain.tld"
      {0} = Firstname
      {1} = Lastname
      {2} = Birthday
      {3} = .ext (if user is external add .ext, if not this is empty)

      .Parameter FormatTeacher
      UPN Format "{0}.{1}@domain.tld"
      {0} = Firstname
      {1} = Lastname

      .Parameter FallbackOwner
      User to be set if ASV does not proivde a teacher for a given course. 
      This should be a ObjectId, to find out query:
      Get-AzureADUser -ObjectId >UPN< | select objectid

      .Parameter Skip12
      Does not created classes for the 12th form.

      .Parameter WhatIf
      Only prints to console, no changes to AzureAD will be made
 
      .Parameter Debug
      Can only be enabled when whatif is also enabled. Whill skip checks wether or not a class is allready present in O365.
      This can be usefull for verifiying wether or not the correct number of students has been added to all groups.
  #>
  param
  (
    [parameter(Mandatory = $true,ValueFromPipeline = $true)]$Data,
    [parameter(Mandatory = $true)]$FormatPupil,
    [parameter(Mandatory = $true)]$FormatTeacher,
    [parameter(Mandatory=$true)]$FallbackOwner,
    $Skip12 = $false,
    $SingleStepMode = $false,
    $DebugMode = $false,
    $WhatIf = $false
  )
  
  if(!$WhatIf -and $DebugMode){throw "Debug and WhatIf have to be enabled simultaniously"}

  $allusers = Get-AadUserHashTable
  $allclasses = @{}; Get-MgGroup -All | % { if(-not $allclasses.ContainsKey($_.DisplayName)){ $allclasses.Add($_.DisplayName, $_) } }
  
  $groupToClass = Generate-ClassToGroupHashTable -data $Data

  $schuelerToObj = Generate-SchuelerIdToObjTable -data $Data -aadusers $allusers -Format $FormatPupil
  $teacherToObj = Generate-TeacherIdToObjTable -data $Data -aadusers $allusers -Format $FormatTeacher
  
  $unterrichtsElementToSchueler = Generate-CoursesStudentTbl -data $Data
  
  $out = @{}
  $Data.Unterrichtselemente | % {
    
    $klasse = $groupToClass.($_.KlassenGruppeId)
    if($null -eq $klasse)
    {
      Write-Host "[DBG] NO class found for id: $($_.KlassenGruppeId)"
    }
    
    if( $out.ContainsKey($_.Bezeichnung) )
    {
      ( $out.($_.Bezeichnung) ).Unterrichtselemente += @(($_.Id))
    }
    else
    {
      $val = New-Object PSObject
      $val | Add-Member -MemberType NoteProperty -Name Fach -Value ($Data.Faecher.($_.FachId))
      $val | Add-Member -MemberType NoteProperty -Name Unterrichtselemente -Value @(($_.Id))
      $val | Add-Member -MemberType NoteProperty -Name Klasse -Value $klasse
      $val | Add-Member -MemberType NoteProperty -Name Bezeichnung -Value ($_.Bezeichnung)
      $val | Add-Member -MemberType NoteProperty -Name Lehrkraft -Value ($_.LehrkraftId)
      $val | Add-Member -MemberType NoteProperty -Name Koppel -Value ($_.IsPseudoKoppel)
      
      $out.Add( ($_.Bezeichnung) , $val)
    }
  }
  
  $created_teams = @{}
  if($WhatIf){ $DbgOut = @{} }
  foreach($o in $out.GetEnumerator()) 
  {
    if($Skip12 -and $o.Value.Klasse -match "^12$"){continue}
    if( $o.Value.Klasse -match "^(11|12).*$" )
    {
      $dn = "[{0}] {1} - {2}" -f $o.Value.Klasse,$o.Value.Bezeichnung,$o.Value.Fach
    }
    elseif( !$o.Value.Koppel )
    {
      $dn = "{0} - {1}" -f $o.Value.Bezeichnung,$o.Value.Fach
    }
    else
    {
      $dn = "{0} - {1}" -f ($o.Value.Klasse),($o.Value.Fach)
    }
    
    if($allclasses.ContainsKey($dn) -and !$DebugMode)
    {
      continue
    }  
    
    if(($teacherToObj.($o.Value.Lehrkraft) -eq $null) -or ($teacher -eq $null))
    {
      $teacher = $FallbackOwner
    } else {
      $teacher = ($teacherToObj.($o.Value.Lehrkraft))[0]
    }
    
    if(! $created_teams.ContainsKey($dn))
    {
      if(!$WhatIf)
      {
        Write-Host "[CREATE] Team $dn"
        $team = New-Team -DisplayName $dn -Description $dn -Template EDU_Class -Owner $teacher
        $created_teams.Add($dn,$team)
      }
      else { 
        #Write-Host "[WhatIf] Create team $dn"
        $DbgOut.Add($dn,$null)
        $created_teams.Add($dn,'WhatIf')
      }
    } else {
      $team = New-Object psobject
      $team | Add-Member -MemberType NoteProperty -Name GroupId -Value ($created_teams.$dn.GroupId)
    }
    
    $course_students = @()
    foreach ($ue in $o.Value.Unterrichtselemente)
    {
      foreach($s in $unterrichtsElementToSchueler.$ue)
      {
        $course_students += ($schuelerToObj.$s)
      }
    }
    
    $iterations = [Math]::Ceiling($course_students.Count / 20)
  
    for($i = 1; $i -le $iterations; $i++)
    {
    
      $pupil_to_add = @'
{
  "members@odata.bind": [
'@

      for($c = $i*20-20; $c -lt $i*20; $c++)
      {
        # If the size of the array is to be exceeded skip execution of this loop
        if($c -ge $course_students.Count){break}
        $pupil_to_add += @"

    "https://graph.microsoft.com/v1.0/directoryObjects/{$($course_students[$c])}",
"@
      }
      $pupil_to_add = $pupil_to_add -replace ".{1}$"
      $pupil_to_add += @'

  ]
}
'@
      if(!$WhatIf)
      {
          Write-Host "[CREATE] Added $($c) students to course $($dn) in $($i) out of $($iterations) batches."
          Update-MgGroup -GroupId $team.GroupId -BodyParameter $pupil_to_add 2> $null
      } else {
          #Write-Host "[WhatIf] Added a total of $($c) students to course $($dn) in $($i) out of $($iterations) batches."
          $DbgOut.$dn = $c
      }
    }
    $team = $null
    if($SingleStepMode)
    {
      while( (Read-Host -Prompt "Create next class? [y]es or [n]o") -eq "n" )
      {
        Write-Host 'To exit press CTRL+C'
      }
    }
    
  }
  if($WhatIf){return $DbgOut}
}
