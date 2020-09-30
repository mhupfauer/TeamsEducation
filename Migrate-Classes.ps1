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
      $klassendata.Add([int]$kg.KlassenGruppenId, $k.Klassenname)
    }
  }
  return $klassendata
}

function Generate-ClassGroupsToStudentHashTable
{
  param
  (
    [Parameter(Mandatory=$true)]
    $data
  )
  $students = @{}
  foreach ($s in $data.Klassen.Klassengruppen)
  {
    $students.Add([int]$s.KlassenGruppenId, $s.Klassenliste)
  }
  return $students
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
    foreach($klassengruppe in $klasse.KlassenGruppen)
    {
      foreach($schueler in $klassengruppe.Klassenliste)
      {
        $upn = Get-Upn -vorname ($schueler.Vorname) -nachname ($schueler.Familienname) -gebdat ($schueler.GebDatum) -format $Format
        $SchuelerIdToObjTable.($schueler.SchuelerId) += @(($aadusers.$upn))
      }
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
 
      .Parameter Suffix
      Suffix after @ in UPN firstname.lastname@SUFFIX (somedomain.tld)

      .Parameter IncludeSeniors
      Wether or not to import classes from 11th or 12th form

      .Example
      # Creates class teams
      Start-ClassMigration -data $data -Suffix myschool.tld -IncludeSeniors $false
  #>
  param
  (
    [parameter(Mandatory = $true,ValueFromPipeline = $true)]$Data,
    [parameter(Mandatory = $true)]$FormatPupil,
    [parameter(Mandatory = $true)]$FormatTeacher,
    [parameter(Mandatory=$true)]$FallbackOwner,
    $WhatIf = $false
  )

  $allusers = Get-AadUserHashTable
  $allclasses = @{}; Get-AzureADGroup -All $true | % { $allclasses.Add($_.DisplayName, $_) }
  
  $groupToClass = Generate-ClassToGroupHashTable -data $Data
  $groupToStudents = Generate-ClassGroupsToStudentHashTable -data $Data
  
  $schuelerToObj = Generate-SchuelerIdToObjTable -data $Data -aadusers $allusers -Format $FormatPupil
  $teacherToObj = Generate-TeacherIdToObjTable -data $Data -aadusers $allusers -Format $FormatTeacher
  
  $out = @{}
  $Data.Unterrichtselemente | % {
    
    $klasse = $groupToClass.[int]$_.KlassenGruppeId
    if($null -eq $klasse)
    {
      Write-Host "[DBG] NO class found for id: $($_.KlassenGruppeId)"
    }
    $lehrkraft = $_.LehrkraftId
    
    #TODO PLACE ! INSIDE IF STATEMENT
    if( ($klasse -match '11' -or $klasse -match '12') )
    {      
      $val = New-Object PSObject
      $val | Add-Member -MemberType NoteProperty -Name Fach -Value ($Data.Faecher.[int]$_.FachId)
      $val | Add-Member -MemberType NoteProperty -Name Klasse -Value $klasse
      $val | Add-Member -MemberType NoteProperty -Name Bezeichnung -Value ($_.Bezeichnung)
      $val | Add-Member -MemberType NoteProperty -Name Klassenliste -Value ($groupToStudents.[int]$_.KlassenGruppeId)
      $val | Add-Member -MemberType NoteProperty -Name Lehrkraft -Value $lehrkraft
      $val | Add-Member -MemberType NoteProperty -Name Koppel -Value ($_.IsPseudoKoppel)
      
      if( $out.ContainsKey($_.Bezeichnung) )
      {
        ( $out.($_.Bezeichnung) ).Klassenliste += ($groupToStudents.[int]$_.KlassenGruppeId)
      }
      else
      {
        $out.Add( ($_.Bezeichnung) , $val)
      }
    } 
  }
  
  if($WhatIf){ $DbgOut = New-Object -TypeName "System.Collections.ArrayList" }
  
  foreach($o in $out.GetEnumerator()) 
  {
    $teacher = Get-NullSaveStrFromHashTable -Table $teacherToObj -FallbackString $FallbackOwner -LookupKey $o.Value.Lehrkraft
    
    $dn = "{0} - {1}" -f ($o.Value.Klasse),($o.Value.Fach)
    if( (!$o.Value.Koppel) -or ($o.Value.Klasse -match "Q") )
    {
      $dn = $o.Value.Bezeichnung
    }
    
    if($WhatIf)
    {
      Write-Host "[WHATIF] Would create Class: $($dn) | Subject: $($o.Value.Fach) | Pupil count: $($o.Value.Klassenliste.Count)" 
      $o.Value | Add-Member -MemberType NoteProperty -Name DisplayName -Value $dn
      $DbgOut.Add($o.Value)
    }
    else
    {
      Write-Host "[CREATE] $($o.Value.Bezeichnung)"
      
      $team = New-Team -DisplayName $dn -Template EDU_Class -Owner ($teacher)
    
      foreach ($s in $o.Value.Klassenliste)
      {
        $obj = Get-NullSaveStrFromHashTable -Table $schuelerToObj -LookupKey $s.SchuelerId
        Write-Host "[CREATE] Add user $obj"
        Add-TeamUser -GroupId $team.GroupId -User $obj -Role Member
      }
      
      $team = $null
    }
  }
  if($WhatIf){return $DbgOut}
  return
}
