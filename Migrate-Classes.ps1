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
    $Suffix,    
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
        $upn =  '{0}.{1}.{2}.schueler@{3}' -f (Remove-DiacriticsAndSpaces $schueler.Vorname),$schueler.GebDatum,(Remove-DiacriticsAndSpaces $schueler.Familienname),$Suffix
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
    $Suffix,
    [parameter(
        Mandatory = $true
    )]
    $aadusers
  )

  $TeacherIdToObjTable = @{}
  
  foreach($teacher in $data.Lehrer)
  {
    $upn =  '{0}.{1}@{2}' -f (Remove-DiacriticsAndSpaces $teacher.Vorname),(Remove-DiacriticsAndSpaces $teacher.Familienname),$Suffix
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
    [parameter(
        Mandatory = $true,
        ValueFromPipeline = $true
    )]
    $Data,
    [parameter(
        Mandatory = $true
    )]
    $Suffix,
    [bool]$IncludeSeniors = $false
  )

  $allusers = Get-AadUserHashTable
  
  $groupToClass = Generate-ClassToGroupHashTable -data $Data
  $groupToStudents = Generate-ClassGroupsToStudentHashTable -data $Data
  
  $schuelerToObj = Generate-SchuelerIdToObjTable -data $Data -aadusers $allusers -Suffix $Suffix
  $teacherToObj = Generate-TeacherIdToObjTable -data $Data -aadusers $allusers -Suffix $Suffix
  
  $out = @{}
  $Data.Unterrichtselemente | % {
    
    $klasse = $groupToClass.[int]$_.KlassenGruppeId
    $lehrkraft = $_.LehrkraftId
    
    if(! (!$IncludeSeniors -and ($klasse -match '11' -or $klasse -match '12')) )
    {      
      $key = (($Data.Faecher.[int]$_.FachId) + '.' + $klasse)
      
      $val = New-Object PSObject
      $val | Add-Member -MemberType NoteProperty -Name Klassenliste -Value ($groupToStudents.[int]$_.KlassenGruppeId)
      $val | Add-Member -MemberType NoteProperty -Name Lehrkraft -Value $lehrkraft
      
      if($out.ContainsKey($key))
      {
        $out[$key].Klassenliste += $val.Klassenliste
      }
      else
      {
        $out.Add($key, $val)
      }
    } 
  }
  
  foreach($o in $out.GetEnumerator()) 
  { 
    $fach,$klasse = $o.Key.Split('.')
    
    $teacher = $teacherToObj.($o.Value.Lehrkraft)
    $team = New-Team -DisplayName ("{0} - {1}" -f $klasse,$fach) -Template EDU_Class -Owner $teacher[0].ToString()
    
    foreach ($s in $o.Value.Klassenliste)
    {
      $obj = $schuelerToObj.($s.SchuelerId)
      Add-TeamUser -GroupId $team.GroupId -User $obj[0].ToString() -Role Member
    }
  }
}
