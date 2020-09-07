function Start-MigrationEnv
{
  Write-Host -ForegroundColor Yellow "[Notice] Your account needs to be global administrator of the O365 tenant."
  Start-Sleep -Seconds 2
  $mfa = Read-Host -Prompt 'Does your account use Multi-Factor Authentication? | [y]es, [n]o'
  if($mfa.ToString() -eq "n")
  {
    $cred = Get-Credential
  }
  
  Connect-AzureAD -Credential $cred
  Connect-MicrosoftTeams -Credential $cred
  Connect-MsolService -Credential $cred  
} 