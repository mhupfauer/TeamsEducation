function createXmlObj
{
  param
  (
    $XMLPath
  )
  $asv = New-Object -TypeName System.Xml.XmlDocument
  $asv.Load($XMLPath)
  return $asv
}

function transformAsvData
{
  param
  (
    $asvData,
    $longClassNames
  )
  $base = $asvData.asv_export.schulen.schule
  $unterrichts = @()
  $klassen = @()
  $faecher = @{}
  $teacher = @()
  
  foreach($i in $base.unterrichtselemente.unterrichtselement)
  {
    if($i.klassengruppe_id -eq $null)
    {
      continue
    }
    
    $koppel = $true
    if($null -ne $i.koppel) 
    { 
      $koppel = $i.koppel.is_pseudokoppel."#cdata-section"
    }
    
    $objin = New-Object -TypeName PSObject
    $objin | Add-Member -MemberType NoteProperty -Name SynKey -Value ($i.lehrkraft_id + "." + $i.klassengruppe_id +"." + $i.fach_id )
    $objin | Add-Member -MemberType NoteProperty -Name Id -Value $i.xml_id
    $objin | Add-Member -MemberType NoteProperty -Name LehrkraftId -Value $i.lehrkraft_id
    $objin | Add-Member -MemberType NoteProperty -Name KlassenGruppeId -Value $i.klassengruppe_id
    $objin | Add-Member -MemberType NoteProperty -Name FachId -Value $i.fach_id
    $objin | Add-Member -MemberType NoteProperty -Name Bezeichnung -Value $i.bezeichnung."#cdata-section"    
    $objin | Add-Member -MemberType NoteProperty -Name IsPseudoKoppel -Value ([System.Convert]::ToBoolean($koppel))
    
    $unterrichts += $objin
  }

  foreach($s in $base.klassen.klasse)
  {
    $objin = New-Object -TypeName PSObject
    $objin | Add-Member -MemberType NoteProperty -Name Id -Value $s.xml_id
    if($longClassNames)
    {
      $objin | Add-Member -MemberType NoteProperty -Name Klassenname -Value $s.klassenname_lang."#cdata-section"
    }
    else
    {
      $objin | Add-Member -MemberType NoteProperty -Name Klassenname -Value $s.klassenname."#cdata-section"
    }
    
    $klassengruppen = @()
    foreach ($k in $s.klassengruppen.klassengruppe)
    {
      $klassendata = New-Object -TypeName psobject
      $klassendata | Add-Member -MemberType NoteProperty -Name KlassenGruppenId -Value $k.xml_id
      
      $schueler = @()
      foreach ($ss in $k.schuelerliste.schuelerin)
      {
        $schuelerdata = New-Object -TypeName PSObject
        
        $schuelerdata | Add-Member -MemberType NoteProperty -Name SchuelerId -Value $ss.xml_id
        
        $vorname = ($ss.rufname."#cdata-section").Replace(" ","-")
        $schuelerdata | Add-Member -MemberType NoteProperty -Name Vorname -Value $vorname
        
        $familienname = $ss.familienname."#cdata-section".Replace(" ","-")
        $schuelerdata | Add-Member -MemberType NoteProperty -Name Familienname -Value $familienname
        
        $schuelerdata | Add-Member -MemberType NoteProperty -Name GebDatum -Value $ss.geburtsdatum."#cdata-section"
        
        $anschriftstext = $ss.schueleranschriften.schueleranschrift[0].anschrift.anschrifttext.'#cdata-section'
        $schuelerdata | Add-Member -MemberType NoteProperty -Name Anschriftstext -Value $anschriftstext
        
        $strasse = $ss.schueleranschriften.schueleranschrift[0].anschrift.strasse.'#cdata-section'
        $schuelerdata | Add-Member -MemberType NoteProperty -Name Strasse -Value $strasse
        
        $ort = $ss.schueleranschriften.schueleranschrift[0].anschrift.ortsbezeichnung.'#cdata-section'
        $schuelerdata | Add-Member -MemberType NoteProperty -Name Ort -Value $ort
        
        $plz = $ss.schueleranschriften.schueleranschrift[0].anschrift.postleitzahl.'#cdata-section'
        $schuelerdata | Add-Member -MemberType NoteProperty -Name PLZ -Value $plz
        
        $hsnr = $ss.schueleranschriften.schueleranschrift[0].anschrift.nummer.'#cdata-section'
        $schuelerdata | Add-Member -MemberType NoteProperty -Name HausNummer -Value $hsnr
        
        $besfaecher = @(); $ss.besuchte_faecher | % { $_.besuchtes_fach.unterrichtselemente | % {$besfaecher += $_.unterrichtselement_id}}
        $schuelerdata | Add-Member -MemberType NoteProperty -Name BesuchteFaecher -Value ($besfaecher)
        
        $schueler += $schuelerdata
      }
      
      $klassendata | Add-Member -MemberType NoteProperty -Name Klassenliste -Value $schueler
      
      $klassengruppen += $klassendata
    }
        
    $objin | Add-Member -MemberType NoteProperty -Name KlassenGruppen -Value $klassengruppen
    $klassen += $objin
  }
  
  foreach ($f in $base.faecher.fach)
  {
    $faecher.Add($f.xml_id, $f.anzeigeform."#cdata-section")
  }
  
  $lehrerMap = @{}
  foreach ($l in $base.lehrkraefte.lehrkraft)
  {
    $lehrerMap.Add([int]$l.lehrkraftdaten_nicht_schulbezogen_id, $l.xml_id)
  }
  
  foreach($t in $asvData.asv_export.lehrkraftdaten_nicht_schulbezogen_liste.lehrkraftdaten_nicht_schulbezogen)
  {
    $objin = New-Object -TypeName PSObject
    $objin | Add-Member -MemberType NoteProperty -Name TeacherId -Value $lehrerMap.Get_item([int]$t.xml_id)
    
    $vorname = ($t.vornamen."#cdata-section".split(" "))[0]
    $objin | Add-Member -MemberType NoteProperty -Name Vorname -Value $vorname
    
    $familienname = $t.familienname."#cdata-section".replace(" ","-")
    $objin | Add-Member -MemberType NoteProperty -Name Familienname -Value $familienname
    $teacher += $objin
  }
    
  $out = New-Object -TypeName PSObject
  $out | Add-Member -MemberType NoteProperty -Name Unterrichtselemente -Value ($unterrichts | Sort-Object -Property SynKey | Get-Unique -AsString)
  $out | Add-Member -MemberType NoteProperty -Name Klassen -Value $klassen
  $out | Add-Member -MemberType NoteProperty -Name Faecher -Value $faecher
  $out | Add-Member -MemberType NoteProperty -Name Lehrer -Value $teacher
  return $out
    
}

function Get-DataFromAsvXml
{
  <#
      .Synopsis
      Reads ASV Data and returns a custom object.

      .Description
      Returns ASV Data as custom object readable by this module

      .Parameter XMLPath
      Path to export.csv (C:\export\export.xml)

      .Parameter LongClassNames
      If $true (default) long classnames will be used. If $false short versions will be used.

      .Example
      # Get data from asv and store in $data.
      $data Get-DataFromAsvXml -XMLPath C:\users\myuser\Documents\ASV-Export\export.xml
  #>
  param
  (
    [Parameter(Mandatory = $true)]
    [string]$XMPath,
    [bool]$LongClassNames = $true    
  )
  $asv = createXmlObj -XMLPath $XMPath
  return transformAsvData -asvData $asv -longClassNames $LongClassNames
}