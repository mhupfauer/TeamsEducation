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
  
  foreach($schueler in $data.Klassen.KlassenGruppen.Klassenliste)
  {
    $upn = Get-Upn -vorname ($schueler.Vorname) -nachname ($schueler.Familienname) -gebdat ($schueler.GebDatum) -format $Format
    $SchuelerIdToObjTable.($schueler.SchuelerId) += @(($aadusers.$upn))
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
      $CourseStudentMap.$bf += @(($kl.SchuelerId))
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
    [parameter(Mandatory=$true)]$StdPath,
    $WhatIf = $false
  )

  $allusers = Get-AadUserHashTable
  $allclasses = @{}; Get-AzureADGroup -All $true | % { $allclasses.Add($_.DisplayName, $_) }
  
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
  
  if($WhatIf){ $DbgOut = New-Object -TypeName "System.Collections.ArrayList" }
  
  foreach($o in $out.GetEnumerator()) 
  {
    if( $o.Value.Klasse -match "^(11|12)Q$" )
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
    
    if($allclasses.ContainsKey($dn))
    {
      continue
    }  
    
    $teacher = Get-NullSaveStrFromHashTable -Table $teacherToObj -FallbackString $FallbackOwner -LookupKey $o.Value.Lehrkraft
      
    if(!$WhatIf)
    {
      Write-Host "[CREATE] team $dn"
      $team = New-Team -DisplayName $dn -Template EDU_Class -Owner ($teacher)
    }
    else { Write-Host "[WhatIf] Create team $dn"}
    
    foreach ($ue in $o.Value.Unterrichtselemente)
    {
      foreach($s in $unterrichtsElementToSchueler.$ue)
      {
        if(!$WhatIf)
        {
          Write-Host "[CREATE] Add user to team: $dn"
          [string]$obj = $schuelerToObj.$s
          Add-TeamUser -User $obj -GroupId $team.GroupId -Role Member
        }
        else
        {
          #Write-Host "[WhatIf] Would add user to $dn"
        }
      }
    }
        
    $team = $null
  }
  if($WhatIf){return $DbgOut}
  return
}
