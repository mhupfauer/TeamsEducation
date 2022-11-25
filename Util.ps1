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
    $inputString = $inputString.Replace("Ä","Ae")
    $inputString = $inputString.Replace("Ö","Oe")
    $inputString = $inputString.Replace("Ü","Ue")
    
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
  Get-MgUser -All | % { $aadusers.Add($_.UserPrincipalName, $_.Id) }
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
    $extemptListPath
  )
  
  if ($extemptListPath -eq $null)
  {
    return @{}
  }
  
  return (Import-Csv -Path $extemptListPath -Delimiter ";").UPN
}

function Get-NullSaveStrFromHashTable
{
  param
  (
    [parameter(Mandatory=$true)]
    $Table,
    [parameter(Mandatory=$true)]
    [AllowNull()] 
    $LookupKey,
    $FallbackString
  )
    if($null -eq $LookupKey)
    {
      return $FallbackString
    }
    
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
    $klasse,
    [parameter(Mandatory=$true)] $format
  )
  
  $vorname = Remove-DiacriticsAndSpaces -inputString $vorname
  $nachname = Remove-DiacriticsAndSpaces -inputString $nachname
  $gebdat = $gebdat.Split(".")[2]
  $ext = ""
  if($klasse -like '*ext')
  {
    $ext = ".ext"
  }
  
  return ($format -f $vorname,$nachname,$gebdat,$ext)
}

function Update-UserLicenses
{
  param
  (
    $users,
    $sku_to_remove,
    $sku_to_add
  )
  
  $subscriptionFrom=$sku_to_remove
  $subscriptionTo=$sku_to_add
  
  foreach($u in $users.GetEnumerator())
  {
    # Unassign
    $license = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    $licenses.RemoveLicenses =  (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $subscriptionFrom -EQ).SkuID
    Set-AzureADUserLicense -ObjectId $u -AssignedLicenses $licenses
    # Assign
    $license.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $subscriptionTo -EQ).SkuID
    $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    $licenses.AddLicenses = $License
    Set-AzureADUserLicense -ObjectId $u -AssignedLicenses $licenses
  }
}


function New-BroadcastMessage {

  param(
    $user_pattern,
    $sender_uid,
    $message
  )

  $teachers = Get-MgUser -All:$true | Where-Object {$_.userprincipalname -like $user_pattern}
  
  foreach($t in $teachers)
  {
    $odata = @"
{
  "chatType": "oneOnOne",
  "members": [
    {
      "@odata.type": "#microsoft.graph.aadUserConversationMember",
      "roles": ["owner"],
      "user@odata.bind": "https://graph.microsoft.com/beta/users('$($sender_uid)')"
    },
    {
      "@odata.type": "#microsoft.graph.aadUserConversationMember",
      "roles": ["owner"],
      "user@odata.bind": "https://graph.microsoft.com/beta/users('$($t.Id)')"
    }
  ]
}
"@
  
    $chat = New-MgChat -BodyParameter $odata
    New-MgChatMessage -ChatId $chat.Id -Body @"
{
  "content": "$($message)"
}
"@

  }
}