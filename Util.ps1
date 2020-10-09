function Load-PasswordList
{
  Param(
    [parameter(
        Mandatory = $true
    )]
    $passwordlistpath
  )
  
  $passwordlist = Import-Csv $passwordlistpath
  $passwordvornamename = @{}
  
  $passwordlist | % { $passwordvornamename.Add( ("$($_.Vorname)$($_.Nachname)"), $_.Pass ) }
  
  return $passwordvornamename
}

function Remove-DiacriticsAndSpaces
{
    Param(
        [String]$inputString
    )
    $inputString = $inputString.Replace("ä","ae")
    $inputString = $inputString.Replace("ö","oe")
    $inputString = $inputString.Replace("ü","ue")
    $inputString = $inputString.Replace("ß","ss")
    
    $objD = $inputString.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
 
    for ($i = 0; $i -lt $objD.Length; $i++) {
        $c = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($objD[$i])
        if($c -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
          [void]$sb.Append($objD[$i])
        }
      }
    
    return($sb -replace '[^a-zA-Z0-9\-]', '')
}

function Get-RandomPassword($len)
{
  return -join ((65..90) + (97..122) + (48..57) | Get-Random -Count $len | % {[char]$_})
}

function Get-AadUserHashTable()
{
  $aadusers = @{}
  Get-AzureADUser -All $true | % { $aadusers.Add($_.UserPrincipalName, $_.ObjectId) }
  return $aadusers
}

function Get-LicensesToAssign()
{
  param
  (
    [parameter(
        Mandatory = $true
    )]
    $Plans
  )
  
  $LicensesToAssign = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
  
  foreach ($p in $Plans)
  {
    $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    $License.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $p -EQ).SkuID
    $LicensesToAssign.AddLicenses += $License
  }  
  
  return $LicensesToAssign
}

function Get-ExemptList
{
  param
  (
    [parameter(
        Mandatory = $true
    )]
    $extemptListPath
  )
  
  
  $listout = @{}
  $rawlist = Import-Csv -Path $extemptListPath

  foreach($r in $rawlist)
  {
    $vorname = Remove-DiacriticsAndSpaces $r.Vorname
    $nachname = Remove-DiacriticsAndSpaces $r.Nachname
    $listout.Add("$vorname.$nachname@$Suffix", "NO LICENSE")
  }
  return $listout
}

function Get-NullSaveStrFromHashTable
{
  param
  (
    [parameter(Mandatory=$true)]
    $Table,
    [parameter(Mandatory=$true)]
    $LookupKey,
    $FallbackString
  )
  
    $outObj = $Table.$LookupKey
    if($outObj -eq $null)
    {
      $out = $FallbackString
    }
    else
    {
      $out = $outObj
    }
    return $out
}

function Get-Upn
{
  param
  (
    [parameter(Mandatory=$true)] $vorname,
    [parameter(Mandatory=$true)] $nachname,
    $gebdat = "0.0.0",
    [parameter(Mandatory=$true)] $format
  )
  
  $vorname = Remove-DiacriticsAndSpaces -inputString $vorname
  $nachname = Remove-DiacriticsAndSpaces -inputString $nachname
  $gebdat = $gebdat.Split(".")[2]
  
  return ($format -f $vorname,$nachname,$gebdat)
}