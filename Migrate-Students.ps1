function Start-StudentMigration
{
<#
 .Synopsis
  Creates students in Microsoft Teams.

 .Description
  Reads ASV Data from Get-DataFromAsvXml and creates student user accounts based on ASV Data.

 .Parameter data
  Object returned from Get-DataFromAsvXml
 
 .Parameter AADUserOutput
  Path where output file of created users sould be stored.

 .Parameter Format
  UPN Format "{0}.{1}.{2}.schueler@domain.tld"
  {0} = Firstname
  {1} = Lastname
  {2} = Birthday

 .Parameter PasswordListPath
  Path to .csv file with exisiting passwords. Structure (vorname,nachname,pass)

 .Parameter WhatIf
  Does not create users in production system. Only prints users to console and creates output file.

 .Example
  # Creates students in asv.
  Start-StudentMigration -data $data -AADUserOutput C:\users\docuemtns\created-students.csv -Suffix myschool.tld
#>
  param
  (
    [parameter(
        Mandatory = $true,
        ValueFromPipeline = $true
    )]
    $data,
    [Parameter(
        Mandatory = $true
    )]
    $AADUserOutput,
    [Parameter(
        Mandatory = $true
    )]
    $Format,
    $PasswordListPath,
    $WhatIf = $false
  )
  
  $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
  $PasswordProfile.ForceChangePasswordNextLogin = $true
  
  $LicensesToAssign = Get-LicensesToAssign -Plans @('STANDARDWOFFPACK_STUDENT')
  
  if($null -ne $PasswordListPath)
  {
    $PasswordList = Load-PasswordList -passwordlistpath $PasswordListPath
  }
  
  $newAADUsers = @()
  $aadusers = Get-AadUserHashTable

  
  foreach ($k in $data.Klassen)
  {

    foreach ($kg in $k.KlassenGruppen)
    {
      foreach ($kl in $kg.Klassenliste)
      {
        $upn = Get-Upn -vorname ($kl.Vorname) -nachname ($kl.Familienname) -gebdat ($kl.GebDatum) -format $Format
        if (!$aadusers.ContainsKey($upn)) 
        {
          $klasse = $k.Klassenname
          $anrede = $kl.Anschriftstext
          $anschrift = $kl.Strasse
          $hsnr = $kl.HausNummer
          $plz = $kl.PLZ
          $ort = $kl.Ort
          $oldflag = $false
        
          $pass = (Get-RandomPassword(11).ToString()) + "!"
           
          $luser = New-Object psobject
      
          # If password list is set and key with firstlastname exisists stored password
          if($null -ne $PasswordListPath)
          {
            if($null -ne ($PasswordList.("$($vorname)$($nachname)") ) )
            {
              $pass = ($PasswordList.("$($vorname)$($nachname)")).ToString()
              $oldflag = $true
            }
          }
          $PasswordProfile.Password = $pass
        
          if(!$WhatIf)
          {
            Write-Host "[CREATE] Create user $vorname $nachname"
        
            $aad = New-AzureADUser -DisplayName ("$vorname $nachname") -GivenName $vorname -Surname $nachname -UserPrincipalName $upn -PasswordProfile $PasswordProfile -MailNickName $upn.Split("@")[0] -AccountEnabled $true -UsageLocation DE
            Set-AzureADUserLicense -ObjectId $aad.ObjectId -AssignedLicenses $LicensesToAssign      
          
            $luser | Add-Member -MemberType NoteProperty -Name UPN -Value $aad.UserPrincipalName
          } else {
            Write-Host "[WHATIF] Create user $vorname $nachname"
            $luser | Add-Member -MemberType NoteProperty -Name UPN -Value $upn
          }
      
          $luser | Add-Member -MemberType NoteProperty -Name Pass -Value $pass
          $luser | Add-Member -MemberType NoteProperty -Name Nachname -Value $nachname
          $luser | Add-Member -MemberType NoteProperty -Name Vorname -Value $vorname
          $luser | Add-Member -MemberType NoteProperty -Name Geburtsdatum -Value $gebdat
          $luser | Add-Member -MemberType NoteProperty -Name Klasse -Value $klasse
          $luser | Add-Member -MemberType NoteProperty -Name Anrede -Value $anrede
          $luser | Add-Member -MemberType NoteProperty -Name Anschrift -Value $anschrift
          $luser | Add-Member -MemberType NoteProperty -Name Hausnummer -Value $hsnr
          $luser | Add-Member -MemberType NoteProperty -Name PLZ -Value $plz
          $luser | Add-Member -MemberType NoteProperty -Name Ort -Value $ort
          $luser | Add-Member -MemberType NoteProperty -Name OldFlag -Value $oldflag
          $newAADUsers += $luser
        }
      }
    }
  }
  
  $newAADUsers | Export-Csv -Path $AADUserOutput -Encoding UTF8
  return
}