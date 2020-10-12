function Close-LegacyTeams
{
  <#
      .Synopsis
      Archives Teams from previous year.

      .Description
      Removes all team members (not owners) based on regex pattern. Default pattern matches all groups starting with digits 2, 5 to 9 and 10.
      So a 5e - English will be archived where as a 1f5 course will not be. A 2f5 course however will be archived.

      .Parameter pattern
      Regex pattern override. Default ^([2,5-9]|10).*$
 
      .Parameter Prefix
      String that should be appended infornt of archived teams. 
      A taling whitespace will be added by default!

      .Example
      # Archives teams
      Close-LegacyTeams -Prefix "[ARCHIVE 19/20]"
  #>
  param
  (
    $pattern,
    [Parameter(Mandatory=$true)]
    $Prefix
  )
  
  if($null -eq $pattern)
  {
    $pattern = "^([2,5-9]|10).*$"
  } 
  else
  {
    Write-Host -ForegroundColor Red '[ATTENTION] BE EXTRA SURE OF WHAT YOU ARE DOING'
    Write-Host -ForegroundColor Red 'The following groups match your regex pattern:'
  }
  
  $groups = Get-AzureADGroup -All $true | Where-Object {$_.DisplayName -match $pattern}
  ($groups | Sort-Object -Property DisplayName | ft)
  Write-Host 'Are you sure you want to archive these groups? | [Y]es, [n]o'
  $rhost = Read-Host
  if($rhost -ne 'Y')
  {
    return
  }
  
  foreach ($g in $groups)
  {
    $members = Get-AzureADGroupMember -ObjectId $g.ObjectId -All $true
    
    foreach ($m in $members)
    {
      Remove-AzureADGroupMember -ObjectId $g.ObjectId -MemberId $m.ObjectId
    }
    
    Set-AzureADGroup -ObjectId $g.ObjectId 
  }
}

function Remove-LegacyUsers
{
  <#
      .Synopsis
      Removes legacy users from the previous year.

      .Description
      Removes all users from AAD that are no longer present in ASV

      .Parameter data
      Object returned from Get-DataFromAsvXml
 
      .Parameter Force
      Boolean value, if set will delete users without prompt

      .Parameter Format
      UPN Format "{0}.{1}.{2}.schueler@domain.tld"
      {0} = Firstname
      {1} = Lastname
      {2} = Birthday

      .Parameter NoDelete
      HashTable with users to exclude from deletion

      .Parameter WhatIf
      Does not delete users in production system. Only prints users to console.

      .Example
      # Archives teams
      Remove-LegacyUsers -data $data -Format "{0}.{1}.{2}.schueler@schule.tld" -NoDelte @{'marina.mueller.2222.schueler@schule.tld'='';} -WhatIf $true -Force $true
  #>
  param
  (
    [Parameter(Mandatory=$true)]$data,
    [Parameter(Mandatory=$true)]$Format,
    [bool]$Force=$false,
    [HashTable]$NoDelte = @{},
    $WhatIf = $false
  )
    
  $aadusers = Get-AzureADUser -All $true
  $asvusers = @{}
  
  foreach($k in $data.Klassen)
  {
    foreach($kg in $k.KlassenGruppen)
    {
      foreach($kl in $kg.Klassenliste)
      {
        $upn = Get-Upn -vorname ($kl.Vorname) -nachname ($kl.Familienname) -gebdat ($kl.GebDatum) -format $Format
        if(!$asvusers.ContainsKey($upn))
        {
          $asvusers.Add($upn,$null)
        }
      }
    }
  }
  
  $noasvhit = @{}
  foreach ($aad in $aadusers)
  {
    if( (!$asvusers.ContainsKey($aad.UserPrincipalName)) -and (!$NoDelte.Contains($aad.UserPrincipalname)) -and ($aad.UserPrincipalName -match "schueler") )
    {
      $noasvhit.Add($aad.UserPrincipalName, $aad)
    }
  }
  
  Write-Host ("{0} Users to be deleted" -f ($noasvhit.Count))
  $noasvhit.GetEnumerator() | Select-Object -ExpandProperty Value | ft
  
  if($Force)
  {
    $optn = 'Y'
  }
  else
  {
    Write-Host "Do you want to delete those users? [Y/n]"
    if($WhatIf){Write-Host "WhatIf enabled, users will not be deleted"}
    $optn = Read-Host
  }
  
  if($optn -eq 'Y')
  {
    $noasvhit.GetEnumerator() | % { if(!$WhatIf){Remove-AzureADUser -ObjectId $_.Value.ObjectId}; Write-Host "DELETE: $($_.Value.UserPrincipalName)"}
    Write-Host "Users deleted."
  }
  else
  {
    Write-Host "Users not deleted. You may exclude users in a HashTable and pass to parameter -NoDelte"
  }
}
