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
    Get-AzureADGroup -All $true | Where-Object {$_.DisplayName -match $pattern}
    $rhost = Read-Host -Prompt 'Are you sure you want to archive these groups? | [y]es, [n]o'
    if($rhost -ne 'y')
    {
      return
    }
  }
  
  $groups = Get-AzureADGroup -All $true | Where-Object {$_.DisplayName -match $pattern}
  
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
      Removes all users from AAD that are no longer contained in ASV

      .Parameter data
      Object returned from Get-DataFromAsvXml
 
      .Parameter DeletionOutput
      Path where output file of deleted users sould be stored.

      .Parameter Suffix
      Suffix after @ in UPN firstname.lastname@SUFFIX (somedomain.tld)

      .Parameter ExemptListPath
      Path to .csv file with users not to delete. Structure (vorname,nachname)

      .Parameter WhatIf
      Does not delete users in production system. Only prints users to console and creates output file.

      .Example
      # Archives teams
      Close-LegacyTeams -Prefix "[ARCHIVE 19/20]"
  #>
  param
  (
    [Parameter(Mandatory=$true)]$data,
    [Parameter(Mandatory=$true)]$DeletionOutput,
    [Parameter(Mandatory=$true)]$Suffix,
    [Parameter(Mandatory=$true)]$ExemptListPath,
    [Parameter(Mandatory=$true)]$WhatIf
  )
  
  $aadusers = Get-AzureADUser -All $true
  
}