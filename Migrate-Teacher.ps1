﻿<#
 .Synopsis
  Creates teachers in Microsoft Teams.

 .Description
  Reads ASV Data from Get-DataFromAsvXml and creates teacher user accounts based on ASV Data.

 .Parameter data
  Object returned from Get-DataFromAsvXml
 
 .Parameter AADUserOutput
  Path where output file of created users sould be stored.

 .Parameter Suffix
  Suffix after @ in UPN firstname.lastname@SUFFIX (somedomain.tld)

 .Parameter ExemptListPath
  Path to .csv file with teachers not to create. Structure (vorname,nachname)

 .Parameter WhatIf
  Does not create users in production system. Only prints users to console and creates output file.

 .Example
  # Creates students in asv.
  Start-TeacherMigration -data $data -AADUserOutput C:\users\docuemtns\created-teachers.csv -Suffix myschool.tld
#>

function Start-TeacherMigration
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
    $AADUserOutput,
    [parameter(
        Mandatory = $true
    )]
    $Suffix,
    $WhatIf = $false,
    $ExemptListPath
  )
  
  $ExemptList = Get-ExemptList -extemptListPath $ExemptListPath
  
  $aadusers = Get-AadUserHashTable

  $outs = @()
  
  $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
  $PasswordProfile.ForceChangePasswordNextLogin = $true
  $LicensesToAssign = Get-LicensesToAssign -Plans @('STANDARDWOFFPACK_FACULTY', 'OFFICESUBSCRIPTION_FACULTY')

  foreach ($l in $data.Lehrer)
  {
    $vorname = Remove-DiacriticsAndSpaces $l.Vorname
    $nachname = Remove-DiacriticsAndSpaces $l.Familienname
  
    $upn = "$vorname.$nachname@$Suffix"
    
    $pass = (Get-RandomPassword(12).ToString()) + "!"    
    $PasswordProfile.Password = $pass
    
    if ( ! ($ExemptList.ContainsKey($upn) -or $aadusers.ContainsKey($upn)) ) 
    {
      if(! $WhatIf)
      {
        $aad = New-AzureADUser -DisplayName ("$vorname $nachname") -MailNickName ("$vorname.$nachname") -UserPrincipalName $upn -PasswordProfile $PasswordProfile -AccountEnabled $true -UsageLocation DE
        Set-AzureADUserLicense -ObjectId $aad.ObjectId -AssignedLicenses $LicensesToAssign
      }
      else
      {
        Write-Host "[WHATIF] Would create $upn"
      }
      
      $out = New-Object PSObject
      $out | Add-Member -MemberType NoteProperty -Name UPN -Value $upn
      $out | Add-Member -MemberType NoteProperty -Name Nachname -Value $nachname
      $out | Add-Member -MemberType NoteProperty -Name Vorname -Value $vorname
      $out | Add-Member -MemberType NoteProperty -Name Pass -Value $pass
      $outs += $out
    }
  }
  
  $outs | Export-Csv -Path $AADUserOutput
  return 
}